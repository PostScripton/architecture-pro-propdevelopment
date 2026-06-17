# Задание 5. Управление трафиком внутри кластера Kubernetes

## Результат

Файл `non-admin-api-allow.yaml` содержит три сетевые политики для namespace `propdevelopment`.

## Развёртывание подов

Все ресурсы размещаются в namespace `propdevelopment`:

```bash
kubectl create namespace propdevelopment

kubectl run front-end-app --image=nginx --labels role=front-end --expose --port 80 --namespace=propdevelopment
kubectl run back-end-api-app --image=nginx --labels role=back-end-api --expose --port 80 --namespace=propdevelopment
kubectl run admin-front-end-app --image=nginx --labels role=admin-front-end --expose --port 80 --namespace=propdevelopment
kubectl run admin-back-end-api-app --image=nginx --labels role=admin-back-end-api --expose --port 80 --namespace=propdevelopment
```

## Применение сетевых политик

```bash
kubectl apply -f non-admin-api-allow.yaml
```

## Структура политик

**1. `default-deny-ingress`** - запрещает весь входящий трафик для всех подов в namespace по умолчанию (`podSelector: {}`).

**2. `back-end-api-allow-from-front-end`** - разрешает входящий трафик к поду с меткой `role=back-end-api` только от подов с меткой `role=front-end`.

**3. `admin-back-end-api-allow-from-admin-front-end`** - разрешает входящий трафик к поду с меткой `role=admin-back-end-api` только от подов с меткой `role=admin-front-end`.

## Результирующая матрица доступа

- `front-end` -> `back-end-api`: разрешено
- `admin-front-end` -> `admin-back-end-api`: разрешено
- `front-end` -> `admin-back-end-api`: запрещено
- `admin-front-end` -> `back-end-api`: запрещено
- Любой под -> `front-end` / `admin-front-end`: запрещено (нет политики, разрешающей ingress)

## Проверка

```bash
# Запустить временный под в том же namespace и проверить доступность сервисов
kubectl run test-$RANDOM --rm -i -t --image=alpine --namespace=propdevelopment -- sh
# Внутри пода:
/ # wget -qO- --timeout=2 http://back-end-api-app   # доступно только из front-end-app
/ # wget -qO- --timeout=2 http://admin-back-end-api-app   # доступно только из admin-front-end-app
```
