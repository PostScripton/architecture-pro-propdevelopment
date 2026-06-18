#!/bin/bash
# Симуляция инцидента: набор подозрительных действий в кластере,
# которые должны быть зафиксированы в audit.log.
#
# Действия:
#   - попытка доступа к secrets от лица system:serviceaccount:secure-ops:monitoring
#   - создание привилегированного пода
#   - kubectl exec в чужом поде (coredns в kube-system)
#   - "удаление" audit-policy (представлена ConfigMap audit-policy)
#   - создание RoleBinding с правами cluster-admin без согласования

set -e

kubectl create ns secure-ops
kubectl config set-context --current --namespace=secure-ops

kubectl create sa monitoring

# Представление audit-policy в виде объекта кластера, чтобы её удаление попало в журнал.
kubectl create configmap audit-policy --namespace=kube-system \
  --from-file=audit-policy.yaml=audit-policy.yaml

kubectl run attacker-pod --image=alpine --command -- sleep 3600

# Проверка прав и попытка чтения секрета от лица сервис-аккаунта monitoring.
kubectl auth can-i get secrets --as=system:serviceaccount:secure-ops:monitoring || true
kubectl create secret generic app-credentials --from-literal=password=s3cr3t
kubectl get secret app-credentials \
  --as=system:serviceaccount:secure-ops:monitoring || true
kubectl get secret -n kube-system \
  --as=system:serviceaccount:secure-ops:monitoring || true

# Создание привилегированного пода.
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: privileged-pod
spec:
  containers:
    - name: pwn
      image: alpine
      command: ["sleep", "3600"]
      securityContext:
        privileged: true
  restartPolicy: Never
EOF

# kubectl exec в чужом поде (системный под в kube-system).
victim_pod="$(kubectl get pods -n kube-system --field-selector=status.phase=Running \
  -o jsonpath='{.items[0].metadata.name}')"
kubectl exec -n kube-system "$victim_pod" -- cat /etc/resolv.conf || true

# Удаление audit-policy от лица admin (отключение аудита).
kubectl delete configmap audit-policy --namespace=kube-system \
  --as=admin --as-group=system:masters

# Создание RoleBinding с правами cluster-admin без согласования.
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: escalate-binding
  namespace: secure-ops
subjects:
  - kind: ServiceAccount
    name: monitoring
    namespace: secure-ops
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io
EOF
