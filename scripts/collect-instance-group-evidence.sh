#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="${HOME}/diploma"
TF_DIR="${ROOT}/terraform"
ANSIBLE_DIR="${ROOT}/ansible"
EVIDENCE_DIR="${ROOT}/evidence"
INVENTORY="${ANSIBLE_DIR}/inventory/hosts.yml"

mkdir -p "${EVIDENCE_DIR}"

for command in terraform yc ansible jq curl; do
  if ! command -v "${command}" >/dev/null 2>&1; then
    echo "ERROR: required command not found: ${command}" >&2
    exit 1
  fi
done

if [[ ! -d "${TF_DIR}" || ! -d "${ANSIBLE_DIR}" ]]; then
  echo "ERROR: expected project directories under ${ROOT}" >&2
  exit 1
fi

if [[ ! -f "${INVENTORY}" ]]; then
  echo "ERROR: inventory not found: ${INVENTORY}" >&2
  exit 1
fi

cd "${TF_DIR}"

WEB_IG_ID="$(terraform output -raw web_instance_group_id)"
ALB_IP="$(terraform output -raw alb_public_ip)"

{
  echo "# Collection metadata"
  echo "collected_at=$(date --iso-8601=seconds)"
  echo "collector_host=$(hostname)"
  echo "instance_group_id=${WEB_IG_ID}"
  echo "alb_ip=${ALB_IP}"
} > "${EVIDENCE_DIR}/collection-metadata.txt"

{
  echo "# Instance Group"
  yc compute instance-group get --id "${WEB_IG_ID}"
  echo
  echo "# Managed instances"
  yc compute instance-group list-instances --id "${WEB_IG_ID}"
} > "${EVIDENCE_DIR}/instance-group-list.txt"

{
  echo "# Terraform state: Instance Group"
  terraform state show yandex_compute_instance_group.web
} > "${EVIDENCE_DIR}/terraform-instance-group.txt"

{
  echo "# Relevant cloud-init template markers"
  grep -nE \
    'ansible-pull|git_repo|git_revision|systemd|runcmd|packages:' \
    templates/web-cloud-init.yaml.tftpl
} > "${EVIDENCE_DIR}/cloud-init-template.txt"

{
  echo "# web-pull.yml"
  sed -n '1,260p' "${ANSIBLE_DIR}/playbooks/web-pull.yml"
} > "${EVIDENCE_DIR}/web-pull-playbook.txt"

cd "${ANSIBLE_DIR}"

ansible web \
  -i "${INVENTORY}" \
  -m ansible.builtin.ping \
  > "${EVIDENCE_DIR}/ansible-ping.txt"

ansible web \
  -i "${INVENTORY}" \
  -b \
  -m ansible.builtin.shell \
  -a '
    set -eu

    echo "inventory_host={{ inventory_hostname }}"
    echo "hostname=$(hostname)"
    echo "addresses=$(hostname -I)"
    echo "boot_id=$(cat /proc/sys/kernel/random/boot_id)"

    cloud-init status --long

    test -x /usr/local/sbin/diploma-ansible-pull
    test -f /etc/systemd/system/diploma-ansible-pull.service
    test -f /etc/systemd/system/diploma-ansible-pull.timer

    test "$(systemctl is-enabled diploma-ansible-pull.timer)" = "enabled"
    test "$(systemctl is-active diploma-ansible-pull.timer)" = "active"
    test "$(systemctl show diploma-ansible-pull.service -p Result --value)" = "success"

    test -d /opt/diploma/.git
    echo "git_remote=$(git -C /opt/diploma remote get-url origin)"
    echo "git_revision=$(git -C /opt/diploma rev-parse HEAD)"
    echo "git_branch=$(git -C /opt/diploma branch --show-current)"

    test -s /var/lib/diploma/ansible-pull-success
    grep -q "^status=success$" /var/lib/diploma/ansible-pull-success
    cat /var/lib/diploma/ansible-pull-success

    nginx -t
    test "$(systemctl is-enabled nginx)" = "enabled"
    test "$(systemctl is-active nginx)" = "active"

    HTTP_CODE="$(curl -sS -o /dev/null -w "%{http_code}" http://127.0.0.1/)"
    test "$HTTP_CODE" = "200"

    echo "timer_enabled=$(systemctl is-enabled diploma-ansible-pull.timer)"
    echo "timer_active=$(systemctl is-active diploma-ansible-pull.timer)"
    echo "service_result=$(systemctl show diploma-ansible-pull.service -p Result --value)"
    echo "nginx_enabled=$(systemctl is-enabled nginx)"
    echo "nginx_active=$(systemctl is-active nginx)"
    echo "http_status=$HTTP_CODE"
    echo "ALL_CHECKS_PASSED"
  ' > "${EVIDENCE_DIR}/web-validation.txt"

ansible web \
  -i "${INVENTORY}" \
  -b \
  -m ansible.builtin.shell \
  -a '
    echo "===== {{ inventory_hostname }} / $(hostname) ====="
    journalctl \
      -u diploma-ansible-pull.service \
      -b \
      -n 120 \
      --no-pager
  ' > "${EVIDENCE_DIR}/ansible-pull-journal.txt"

cd "${TF_DIR}"

{
  echo "# ALB validation"
  echo "alb_ip=${ALB_IP}"
  echo "tested_at=$(date --iso-8601=seconds)"
  echo

  for i in $(seq 1 20); do
    printf "%02d " "${i}"
    curl -sSI --max-time 5 "http://${ALB_IP}/" |
      grep -Ei 'HTTP/|X-Backend-Host' |
      tr '\n' ' '
    echo
    sleep 1
  done
} > "${EVIDENCE_DIR}/alb-validation.txt"

{
  echo "# Evidence collection summary"
  echo
  echo "Files:"
  find "${EVIDENCE_DIR}" -maxdepth 1 -type f -printf '%f\n' | sort
  echo
  echo "Validation markers:"
  grep -c 'ALL_CHECKS_PASSED' "${EVIDENCE_DIR}/web-validation.txt" || true
  echo
  echo "Expected marker count: 2"
} > "${EVIDENCE_DIR}/README.txt"

echo "Evidence collected in: ${EVIDENCE_DIR}"
echo
echo "Validation markers:"
grep 'ALL_CHECKS_PASSED' "${EVIDENCE_DIR}/web-validation.txt" || true
echo
echo "Review before committing:"
echo "  grep -RInE 'token|password|secret|PRIVATE KEY' '${EVIDENCE_DIR}'"
echo "  git status --short '${EVIDENCE_DIR}'"
