# Роли и полномочия в Kubernetes (RBAC)

| Роль | Права роли | Группы пользователей |
| --- | --- | --- |
| `cluster-admin` (встроенная ClusterRole) | Полный доступ ко всем ресурсам кластера, включая секреты и управление RBAC | `cluster-admins` - инфраструктурные DevOps-инженеры, ответственные за кластер |
| `secret-reader` (ClusterRole) | `get`, `list`, `watch` на `secrets` - привилегированный просмотр секретов | `security-team` - специалист по ИБ |
| `cluster-viewer` (ClusterRole) | `get`, `list`, `watch` на `pods`, `services`, `endpoints`, `namespaces`, `configmaps`, `persistentvolumeclaims`, `deployments`, `replicasets`, `statefulsets`, `daemonsets`, `ingresses`, `networkpolicies` (без доступа к `secrets`) | `developers` - разработчики всех доменов; `analysts` - бизнес-аналитики продуктовых команд |
| `namespace-configurator` (ClusterRole) | `get`, `list`, `watch`, `create`, `update`, `patch`, `delete` на `pods`, `services`, `configmaps`, `persistentvolumeclaims`, `deployments`, `statefulsets`, `daemonsets`, `ingresses` | `devops-engineers` - DevOps-инженеры продуктовых команд, которые настраивают деплои в своих неймспейсах |