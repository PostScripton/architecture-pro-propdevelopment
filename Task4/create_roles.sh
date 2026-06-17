#!/bin/bash
# Создание RBAC-ролей в кластере Kubernetes.
# Роль cluster-admin встроена в Kubernetes, остальные создаются этим скриптом.

set -e

echo "Создание RBAC-ролей..."

kubectl apply -f - <<EOF
---
# Привилегированная роль: просмотр секретов
# Назначается специалисту по ИБ для аудита и контроля секретов
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: secret-reader
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list", "watch"]
---
# Роль только на чтение: просмотр ресурсов кластера без секретов
# Назначается разработчикам и бизнес-аналитикам
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: cluster-viewer
rules:
- apiGroups: [""]
  resources:
    - pods
    - pods/log
    - services
    - endpoints
    - namespaces
    - configmaps
    - persistentvolumeclaims
    - events
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources:
    - deployments
    - replicasets
    - statefulsets
    - daemonsets
  verbs: ["get", "list", "watch"]
- apiGroups: ["networking.k8s.io"]
  resources:
    - ingresses
    - networkpolicies
  verbs: ["get", "list", "watch"]
---
# Роль настройки: управление рабочими нагрузками и конфигурацией
# Назначается DevOps-инженерам продуктовых команд
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: namespace-configurator
rules:
- apiGroups: [""]
  resources:
    - pods
    - services
    - endpoints
    - configmaps
    - persistentvolumeclaims
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["apps"]
  resources:
    - deployments
    - replicasets
    - statefulsets
    - daemonsets
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["networking.k8s.io"]
  resources:
    - ingresses
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
EOF

echo "Роли созданы:"
echo "  - secret-reader (привилегированный просмотр секретов)"
echo "  - cluster-viewer (просмотр ресурсов кластера без секретов)"
echo "  - namespace-configurator (настройка рабочих нагрузок и конфигурации)"
echo "  - cluster-admin (встроенная, полный доступ)"
