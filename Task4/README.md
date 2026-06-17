# Задание 4. Защита доступа к кластеру Kubernetes

## Результат

Разработана ролевая модель для Kubernetes RBAC на основе организационной структуры PropDevelopment. Подготовлены три скрипта: создание пользователей, создание ролей и привязка ролей.

## Ролевая модель

Определены четыре роли:

- `cluster-admin` (встроенная) - полный доступ, включая секреты и управление RBAC. Назначена группе `cluster-admins` (инфраструктурные DevOps-инженеры).
- `secret-reader` - привилегированный просмотр секретов. Назначена группе `security-team` (специалист по ИБ).
- `cluster-viewer` - просмотр ресурсов кластера без доступа к секретам. Назначена группам `developers` и `analysts`.
- `namespace-configurator` - создание и изменение рабочих нагрузок и конфигурации. Назначена группе `devops-engineers` (DevOps-инженеры продуктовых команд).

Группы определяются через поле `O` (Organization) в сертификате пользователя. Это позволяет привязывать роли к группам через `ClusterRoleBinding`, а не к отдельным пользователям.

## Файлы

- `roles_table.md` - таблица ролей, их прав и соответствующих групп пользователей.
- `create_users.sh` - создание четырёх тестовых пользователей через сертификаты, подписанные CA Minikube. Пользователи: `devops-admin`, `dev-user`, `security-officer`, `devops-engineer`.
- `create_roles.sh` - создание ClusterRole: `secret-reader`, `cluster-viewer`, `namespace-configurator`.
- `bind_roles.sh` - привязка групп к ролям через ClusterRoleBinding.

## Порядок выполнения

```bash
# 1. Запустить Minikube
minikube start

# 2. Создать пользователей
chmod +x create_users.sh && ./create_users.sh

# 3. Создать роли
chmod +x create_roles.sh && ./create_roles.sh

# 4. Привязать роли
chmod +x bind_roles.sh && ./bind_roles.sh
```