#!/bin/bash
set -e

NAMESPACE="audit-zone"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TASK_DIR="$(dirname "${SCRIPT_DIR}")"

echo "=== Creating namespace with restricted PodSecurity policy ==="
kubectl apply -f "${TASK_DIR}/01-create-namespace.yaml"

echo ""
echo "=== Testing that insecure pods are rejected by PodSecurity Admission ==="

check_rejected() {
    local file="$1"
    echo ""
    echo "Testing: $(basename "${file}")"
    result=$(kubectl apply -f "${file}" 2>&1 || true)
    if echo "${result}" | grep -qiE "violates PodSecurity|forbidden|Error from server"; then
        echo "PASS: pod was correctly rejected by admission controller"
        echo "  $(echo "${result}" | grep -iE 'violates|forbidden|Error' | head -1)"
    else
        echo "FAIL: pod should have been rejected but was not"
        echo "  Output: ${result}"
        exit 1
    fi
}

check_rejected "${TASK_DIR}/insecure-manifests/01-privileged-pod.yaml"
check_rejected "${TASK_DIR}/insecure-manifests/02-hostpath-pod.yaml"
check_rejected "${TASK_DIR}/insecure-manifests/03-root-user-pod.yaml"

echo ""
echo "=== Testing that secure pods are admitted ==="

check_admitted() {
    local file="$1"
    echo ""
    echo "Testing: $(basename "${file}")"
    result=$(kubectl apply -f "${file}" 2>&1)
    if echo "${result}" | grep -qE "created|configured"; then
        echo "PASS: pod was correctly admitted"
    else
        echo "FAIL: pod should have been admitted but was not"
        echo "  Output: ${result}"
        exit 1
    fi
}

check_admitted "${TASK_DIR}/secure-manifests/01-secure.yaml"
check_admitted "${TASK_DIR}/secure-manifests/02-secure.yaml"
check_admitted "${TASK_DIR}/secure-manifests/03-secure.yaml"

echo ""
echo "=== Pod status in namespace ${NAMESPACE} ==="
kubectl get pods --namespace="${NAMESPACE}"

echo ""
echo "=== Cleaning up ==="
kubectl delete -f "${TASK_DIR}/secure-manifests/" 2>/dev/null || true
kubectl delete namespace "${NAMESPACE}" 2>/dev/null || true

echo ""
echo "=== Verification complete: PodSecurity Admission is working correctly ==="
