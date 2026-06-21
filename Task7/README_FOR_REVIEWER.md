# Задание 7. Политики безопасности контейнеров: PodSecurity Admission и OPA Gatekeeper

## Результат

Настроены два уровня контроля безопасности для namespace `audit-zone`:
1. PodSecurity Admission Controller (встроенный механизм Kubernetes).
2. OPA Gatekeeper с кастомными Rego-правилами.

## Структура файлов

- `01-create-namespace.yaml` - namespace `audit-zone` с уровнем PodSecurity `restricted`.
- `insecure-manifests/` - три намеренно небезопасных пода:
  - `01-privileged-pod.yaml` - контейнер с `privileged: true`.
  - `02-hostpath-pod.yaml` - под с монтированием `hostPath`.
  - `03-root-user-pod.yaml` - контейнер с `runAsUser: 0` (root).
- `secure-manifests/` - исправленные версии тех же подов, проходящие политику `restricted`:
  - `01-secure.yaml` - убран `privileged`, добавлены все обязательные поля.
  - `02-secure.yaml` - `hostPath` заменён на `emptyDir`.
  - `03-secure.yaml` - `runAsUser` заменён на 1000, добавлен `runAsNonRoot: true`.
- `gatekeeper/constraint-templates/` - ConstraintTemplate CRD для трёх правил.
- `gatekeeper/constraints/` - Constraint-ресурсы, применяющие правила ко всем Pod.
- `audit-policy.yaml` - политика аудита Kubernetes API Server.
- `verify/verify-admission.sh` - скрипт проверки PodSecurity Admission.
- `verify/validate-security.sh` - скрипт применения и проверки Gatekeeper-ограничений.

## Ключевые решения

### PodSecurity Admission

Namespace помечен тремя метками с уровнем `restricted`:
- `enforce` - блокирует создание несоответствующих подов.
- `audit` - логирует нарушения в аудит-лог.
- `warn` - возвращает предупреждение пользователю.

Уровень `restricted` требует от подов: `runAsNonRoot: true`, `allowPrivilegeEscalation: false`, `capabilities.drop: [ALL]`, `seccompProfile: RuntimeDefault`, запрещает `privileged: true` и `hostPath`-тома.

### OPA Gatekeeper

Три ConstraintTemplate с Rego-правилами:
- `k8spspprivilegedcontainer` - запрещает `securityContext.privileged: true`.
- `k8spsphostfilesystem` - запрещает тома типа `hostPath`.
- `k8spsprunasnonroot` - требует `runAsNonRoot: true` и `readOnlyRootFilesystem: true`.

К каждому шаблону создан Constraint-ресурс, применяющий правило ко всем Pod во всех namespace.

### Политика аудита

Настроена иерархия уровней логирования:
- `RequestResponse` - полное логирование создания/изменения Pod в `audit-zone`.
- `Request` - тела запросов для Secrets, ConfigMaps, ServiceAccounts.
- `Metadata` - изменения RBAC-ресурсов.
- `None` - системные события (health checks, kube-proxy) для уменьшения шума.

## Результаты проверки PodSecurity Admission

Проверка выполнена командой `bash verify/verify-admission.sh` на кластере Kubernetes v1.35.1.

Небезопасные поды отклонены с ошибкой `violates PodSecurity "restricted:latest"`:
- `pod-privileged` - нарушения: `privileged=true`, `allowPrivilegeEscalation`, `capabilities`, `runAsNonRoot`, `seccompProfile`.
- `pod-hostpath` - нарушения: `hostPath`-том, `allowPrivilegeEscalation`, `capabilities`, `runAsNonRoot`, `seccompProfile`.
- `pod-root-user` - нарушения: `runAsUser=0`, `allowPrivilegeEscalation`, `capabilities`, `runAsNonRoot`, `seccompProfile`.

Безопасные поды (`01-secure.yaml`, `02-secure.yaml`, `03-secure.yaml`) приняты admission controller без ошибок.

## Установка Gatekeeper

Для применения Gatekeeper-политик требуется предварительная установка:

```bash
kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/release-3.17/deploy/gatekeeper.yaml
```

После установки применить шаблоны и ограничения:

```bash
bash verify/validate-security.sh
```
