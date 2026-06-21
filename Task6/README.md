# Задание 6. Аудит активности пользователей и обнаружение инцидентов

## Результат

Настроен аудит kube-apiserver в minikube, выполнена симуляция инцидента, журнал `audit.log` проанализирован и подозрительные события выделены в отдельную выжимку.

## Файлы

- `audit-policy.yaml` - политика аудита, подключаемая к kube-apiserver.
- `simulate-incident.sh` - скрипт симуляции подозрительных действий.
- `filter-audit.py` - скрипт фильтрации `audit.log` и формирования выжимки.
- `audit.log` - журнал аудита, собранный во время симуляции.
- `audit-extract.json` - выжимка подозрительных событий.
- `analysis.md` - отчёт по выявленным событиям.

## Настройка среды

Политика аудита подключается "снаружи", без правки динамически генерируемого манифеста изнутри `minikube ssh`:

```bash
# 1. Политика синхронизируется в узел через каталог files minikube
mkdir -p ~/.minikube/files/etc/kubernetes
cp audit-policy.yaml ~/.minikube/files/etc/kubernetes/audit-policy.yaml

# 2. Запуск кластера
minikube start --driver=docker

# 3. К kube-apiserver добавляются флаги аудита и монтирование политики и каталога логов:
#    --audit-policy-file=/etc/kubernetes/audit-policy.yaml
#    --audit-log-path=/var/log/audit.log
#    volume audit-policy (hostPath /etc/kubernetes/audit-policy.yaml)
#    volume audit-log     (hostPath /var/log)
```

Лог пишется в `/var/log/audit.log` на узле и копируется на хост командой `docker cp minikube:/var/log/audit.log ./audit.log`.

В политике из шаблона исправлены две ошибки, из-за которых kube-apiserver не стартовал и часть событий не попадала в журнал с полным телом запроса:

- `group: "*"` недопустимо в схеме политики аудита - заменено на правило-перехватчик `level: Metadata` без ограничения по ресурсам;
- `roles` и `rolebindings` отнесены к корректной API-группе `rbac.authorization.k8s.io`, что позволяет фиксировать `roleRef` у RoleBinding на уровне `RequestResponse`.

## Симуляция инцидента

`simulate-incident.sh` выполняет действия от имени `kubectl` (пользователь `minikube-user`, группа `system:masters`):

- попытка чтения секретов от лица `system:serviceaccount:secure-ops:monitoring`;
- создание привилегированного пода `privileged-pod`;
- `kubectl exec` в системный под в `kube-system`;
- удаление ConfigMap `audit-policy` (представление политики аудита) от лица `admin`/`system:masters`;
- создание RoleBinding `escalate-binding` с правами `cluster-admin` для сервис-аккаунта `monitoring`.

## Фильтрация

```bash
python3 filter-audit.py audit.log audit-extract.json
```

Скрипт обрабатывает только стадию `ResponseComplete` (чтобы не дублировать события) и отбирает запросы по пяти признакам: доступ к секретам, `exec` в под, создание привилегированного пода, выдача `cluster-admin` и изменение/удаление политики аудита. Для каждого события сохраняются инициатор, подменённая личность (`--as`), действие, объект, код ответа, время, IP и `auditID`.

## Найденные события

- `get secrets/app-credentials` и `list secrets` в `kube-system` от лица `monitoring` - отклонены (`403`).
- `create pods/privileged-pod` с `privileged: true` - выполнено (`201`).
- `exec` в `kube-system/coredns-...` - выполнено (`101`).
- `delete configmaps/audit-policy` от лица `admin` (`system:masters`) - выполнено (`200`).
- `create rolebindings/escalate-binding` с `cluster-admin` - выполнено (`201`).

Компрометацией кластера считаются два успешных события: выдача `cluster-admin` сервис-аккаунту и удаление политики аудита. Первопричина - чрезмерные права `system:masters`, неограниченная имперсонизация в RBAC и отсутствие admission-контроля привилегированных подов. Подробности в `analysis.md`.
