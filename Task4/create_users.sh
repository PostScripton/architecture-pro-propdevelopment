#!/bin/bash
# Создание пользователей Kubernetes через сертификаты, подписанные CA Minikube.
# В Kubernetes нет API-объектов для пользователей: идентификация происходит через CN и O в сертификате.
# CN - имя пользователя, O - группа (используется RBAC для привязки ролей).

set -e

MINIKUBE_CA_CRT=~/.minikube/ca.crt
MINIKUBE_CA_KEY=~/.minikube/ca.key
CERTS_DIR=./certs

mkdir -p "$CERTS_DIR"

create_user() {
  local USERNAME=$1
  local GROUP=$2

  echo "--- Создание пользователя: $USERNAME (группа: $GROUP) ---"

  openssl genrsa -out "$CERTS_DIR/$USERNAME.key" 2048 2>/dev/null

  openssl req -new \
    -key "$CERTS_DIR/$USERNAME.key" \
    -out "$CERTS_DIR/$USERNAME.csr" \
    -subj "/CN=$USERNAME/O=$GROUP"

  openssl x509 -req \
    -in "$CERTS_DIR/$USERNAME.csr" \
    -CA "$MINIKUBE_CA_CRT" \
    -CAkey "$MINIKUBE_CA_KEY" \
    -CAcreateserial \
    -out "$CERTS_DIR/$USERNAME.crt" \
    -days 365 2>/dev/null

  kubectl config set-credentials "$USERNAME" \
    --client-certificate="$CERTS_DIR/$USERNAME.crt" \
    --client-key="$CERTS_DIR/$USERNAME.key"

  kubectl config set-context "$USERNAME-context" \
    --cluster=minikube \
    --user="$USERNAME"

  echo "Пользователь $USERNAME создан. Контекст: $USERNAME-context"
}

# Инфраструктурный DevOps - полный доступ к кластеру
create_user "devops-admin" "cluster-admins"

# Разработчик - только просмотр ресурсов
create_user "dev-user" "developers"

# Специалист по ИБ - просмотр ресурсов и секретов
create_user "security-officer" "security-team"

# DevOps продуктовой команды - настройка ресурсов в неймспейсах
create_user "devops-engineer" "devops-engineers"

echo ""
echo "Все пользователи созданы. Сертификаты находятся в директории: $CERTS_DIR"
