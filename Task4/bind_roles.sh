#!/bin/bash
# Привязка групп пользователей к ролям через ClusterRoleBinding.
# Привязка выполняется к группам (Group), а не к отдельным пользователям:
# группа определяется полем O (Organization) в сертификате пользователя.

set -e

echo "Создание привязок ролей..."

kubectl apply -f - <<EOF
---
# cluster-admins -> cluster-admin (встроенная роль, полный доступ)
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: cluster-admins-binding
subjects:
- kind: Group
  name: cluster-admins
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io
---
# developers -> cluster-viewer (только просмотр, без секретов)
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: developers-viewer-binding
subjects:
- kind: Group
  name: developers
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: cluster-viewer
  apiGroup: rbac.authorization.k8s.io
---
# analysts -> cluster-viewer (только просмотр, без секретов)
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: analysts-viewer-binding
subjects:
- kind: Group
  name: analysts
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: cluster-viewer
  apiGroup: rbac.authorization.k8s.io
---
# security-team -> cluster-viewer (просмотр ресурсов)
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: security-team-viewer-binding
subjects:
- kind: Group
  name: security-team
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: cluster-viewer
  apiGroup: rbac.authorization.k8s.io
---
# security-team -> secret-reader (привилегированный просмотр секретов)
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: security-team-secrets-binding
subjects:
- kind: Group
  name: security-team
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: secret-reader
  apiGroup: rbac.authorization.k8s.io
---
# devops-engineers -> namespace-configurator (настройка рабочих нагрузок)
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: devops-engineers-configurator-binding
subjects:
- kind: Group
  name: devops-engineers
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: namespace-configurator
  apiGroup: rbac.authorization.k8s.io
EOF

echo "Привязки ролей созданы:"
echo "  - cluster-admins -> cluster-admin"
echo "  - developers     -> cluster-viewer"
echo "  - analysts       -> cluster-viewer"
echo "  - security-team  -> cluster-viewer + secret-reader"
echo "  - devops-engineers -> namespace-configurator"
