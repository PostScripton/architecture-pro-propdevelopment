#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TASK_DIR="$(dirname "${SCRIPT_DIR}")"

echo "=== Applying Gatekeeper constraint templates ==="
kubectl apply -f "${TASK_DIR}/gatekeeper/constraint-templates/"

echo ""
echo "=== Waiting for Gatekeeper CRDs to be established ==="
for kind in k8spspprivilegedcontainer k8spsphostfilesystem k8spsprunasnonroot; do
    retries=12
    for i in $(seq 1 ${retries}); do
        if kubectl get crd | grep -q "${kind}"; then
            echo "CRD ${kind} is ready"
            break
        fi
        if [ "${i}" -eq "${retries}" ]; then
            echo "Timeout waiting for CRD ${kind} - is Gatekeeper installed?"
            exit 1
        fi
        echo "Waiting for CRD ${kind}... (${i}/${retries})"
        sleep 5
    done
done

echo ""
echo "=== Applying Gatekeeper constraints ==="
kubectl apply -f "${TASK_DIR}/gatekeeper/constraints/"

echo ""
echo "=== Constraint templates installed ==="
kubectl get constrainttemplates

echo ""
echo "=== Constraints installed ==="
kubectl get constraints

echo ""
echo "=== Validation complete: Gatekeeper constraints are configured ==="
