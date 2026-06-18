#!/usr/bin/env python3
"""Фильтрация Kubernetes audit log: выборка подозрительных событий.

На вход подаётся audit.log (формат JSON Lines, по одному событию в строке).
На выходе - audit-extract.json: массив подозрительных событий с пометкой,
по какому признаку событие отобрано.

Использование:
    python3 filter-audit.py [audit.log] [audit-extract.json]
"""
import json
import sys


def user_of(event):
    """Имя инициатора запроса."""
    return event.get("user", {}).get("username", "<unknown>")


def impersonated_of(event):
    """Имя пользователя, под которого выполнялась подмена (--as), если была."""
    imp = event.get("impersonatedUser")
    return imp.get("username") if imp else None


def is_secret_access(event):
    """Чтение секретов (get/list)."""
    ref = event.get("objectRef", {})
    return ref.get("resource") == "secrets" and event.get("verb") in ("get", "list")


def is_pod_exec(event):
    """kubectl exec в под (subresource exec)."""
    ref = event.get("objectRef", {})
    return ref.get("resource") == "pods" and ref.get("subresource") == "exec"


def is_privileged_pod(event):
    """Создание привилегированного пода."""
    ref = event.get("objectRef", {})
    if ref.get("resource") != "pods" or event.get("verb") != "create":
        return False
    spec = (event.get("requestObject") or {}).get("spec", {})
    for container in spec.get("containers", []):
        if (container.get("securityContext") or {}).get("privileged") is True:
            return True
    return False


def is_cluster_admin_binding(event):
    """Создание RoleBinding/ClusterRoleBinding с правами cluster-admin."""
    ref = event.get("objectRef", {})
    if ref.get("resource") not in ("rolebindings", "clusterrolebindings"):
        return False
    if event.get("verb") not in ("create", "update", "patch"):
        return False
    role_ref = (event.get("requestObject") or {}).get("roleRef", {})
    return role_ref.get("name") == "cluster-admin"


def is_audit_policy_change(event):
    """Любое обращение к объекту audit-policy."""
    ref = event.get("objectRef", {})
    name = (ref.get("name") or "")
    return "audit-policy" in name and event.get("verb") in ("delete", "update", "patch")


CHECKS = [
    ("secret-access", is_secret_access),
    ("pod-exec", is_pod_exec),
    ("privileged-pod", is_privileged_pod),
    ("cluster-admin-binding", is_cluster_admin_binding),
    ("audit-policy-change", is_audit_policy_change),
]


def main():
    src = sys.argv[1] if len(sys.argv) > 1 else "audit.log"
    dst = sys.argv[2] if len(sys.argv) > 2 else "audit-extract.json"

    suspicious = []
    with open(src, encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                event = json.loads(line)
            except json.JSONDecodeError:
                continue
            # Берём только итоговую стадию, чтобы не дублировать события.
            if event.get("stage") != "ResponseComplete":
                continue
            reasons = [name for name, check in CHECKS if check(event)]
            if not reasons:
                continue
            suspicious.append({
                "reasons": reasons,
                "user": user_of(event),
                "impersonatedUser": impersonated_of(event),
                "verb": event.get("verb"),
                "objectRef": event.get("objectRef"),
                "responseStatus": event.get("responseStatus"),
                "requestReceivedTimestamp": event.get("requestReceivedTimestamp"),
                "sourceIPs": event.get("sourceIPs"),
                "auditID": event.get("auditID"),
            })

    with open(dst, "w", encoding="utf-8") as out:
        json.dump(suspicious, out, ensure_ascii=False, indent=2)
        out.write("\n")

    print(f"Найдено подозрительных событий: {len(suspicious)}")
    for item in suspicious:
        ref = item["objectRef"] or {}
        target = ref.get("resource", "")
        if ref.get("subresource"):
            target += "/" + ref["subresource"]
        if ref.get("name"):
            target += " " + ref["name"]
        actor = item["user"]
        if item["impersonatedUser"]:
            actor += f" (as {item['impersonatedUser']})"
        code = (item["responseStatus"] or {}).get("code")
        print(f"  [{', '.join(item['reasons'])}] {actor} {item['verb']} {target} -> {code}")


if __name__ == "__main__":
    main()
