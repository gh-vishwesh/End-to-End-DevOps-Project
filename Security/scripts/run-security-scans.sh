#!/usr/bin/env bash
# Run the same security scans as the Jenkins pipeline, locally or on the Jenkins server.
# Only Docker is required; every tool runs in a container.
#
#   ./Security/scripts/run-security-scans.sh                 # repo scans: secrets, IaC misconfig, dependencies
#   ./Security/scripts/run-security-scans.sh <image:tag>     # + container image scan
#
# Reports are written to ./reports/ (gitignored). Exit code is non-zero if a secret is found
# or the image has a fixable CRITICAL vulnerability.
set -uo pipefail

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
TRIVY_IMAGE=${TRIVY_IMAGE:-aquasec/trivy:0.75.0}
REPORTS="$ROOT/reports"
IMAGE=${1:-}
mkdir -p "$REPORTS"
status=0

trivy() {
    docker run --rm \
        -v "$ROOT":/src:ro \
        -v trivy-cache:/root/.cache/ \
        -v /var/run/docker.sock:/var/run/docker.sock \
        "$TRIVY_IMAGE" "$@"
}

echo "==> [1/4] Secret scan (fails on any finding)"
if ! trivy fs --quiet --config /src/Security/trivy/trivy.yaml --scanners secret --exit-code 1 /src \
        | tee "$REPORTS/secrets.txt"; then
    echo "!! Secrets found - see reports/secrets.txt"; status=1
fi

echo "==> [2/4] IaC misconfiguration scan: Terraform, Kubernetes YAML, Dockerfile (report only)"
trivy config --quiet --config /src/Security/trivy/trivy.yaml --ignorefile /src/Security/trivy/.trivyignore \
    /src > "$REPORTS/misconfig.txt"
sed -n '1,/^Legend/p' "$REPORTS/misconfig.txt"
echo "    full report: reports/misconfig.txt"

echo "==> [3/4] Dependency scan: Jenkins_cicd/requirements.txt (report only)"
trivy fs --quiet --config /src/Security/trivy/trivy.yaml --scanners vuln /src/Jenkins_cicd \
    | tee "$REPORTS/dependencies.txt"

if [ -n "$IMAGE" ]; then
    echo "==> [4/4] Image scan: $IMAGE (fails on fixable CRITICAL)"
    trivy image --quiet --severity HIGH,CRITICAL "$IMAGE" > "$REPORTS/image.txt"
    if ! trivy image --quiet --severity CRITICAL --ignore-unfixed --exit-code 1 "$IMAGE"; then
        echo "!! Fixable CRITICAL vulnerabilities in $IMAGE - see reports/image.txt"; status=1
    fi
else
    echo "==> [4/4] Image scan skipped (pass an image, e.g. python_web_application:local)"
fi

echo
[ $status -eq 0 ] && echo "Security scans passed." || echo "Security scans FAILED."
exit $status
