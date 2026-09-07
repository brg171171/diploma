#!/usr/bin/bash

ansible web \
  -i inventory/hosts.yml \
  -b \
  -m ansible.builtin.shell \
  -a '
    set -eu

    echo "===== IDENTITY ====="
    echo "inventory host: ${INVENTORY_HOSTNAME:-unknown}"
    echo "hostname: $(hostname)"
    echo "addresses: $(hostname -I)"
    echo "boot ID: $(cat /proc/sys/kernel/random/boot_id)"

    echo "===== CLOUD-INIT ====="
    cloud-init status --long
    test "$(cloud-init status --format json | jq -r .status)" = "done"

    echo "===== ANSIBLE-PULL FILES ====="
    test -x /usr/local/sbin/diploma-ansible-pull
    test -f /etc/systemd/system/diploma-ansible-pull.service
    test -f /etc/systemd/system/diploma-ansible-pull.timer
    ls -l /usr/local/sbin/diploma-ansible-pull
    ls -l /etc/systemd/system/diploma-ansible-pull.service
    ls -l /etc/systemd/system/diploma-ansible-pull.timer

    echo "===== SYSTEMD ====="
    test "$(systemctl is-enabled diploma-ansible-pull.timer)" = "enabled"
    test "$(systemctl is-active diploma-ansible-pull.timer)" = "active"
    test "$(systemctl show diploma-ansible-pull.service -p Result --value)" = "success"
    echo "timer enabled: $(systemctl is-enabled diploma-ansible-pull.timer)"
    echo "timer active: $(systemctl is-active diploma-ansible-pull.timer)"
    echo "service result: $(systemctl show diploma-ansible-pull.service -p Result --value)"

    echo "===== GIT REPOSITORY ====="
    test -d /opt/diploma/.git
    git -C /opt/diploma remote -v
    echo "revision: $(git -C /opt/diploma rev-parse --short HEAD)"
    echo "branch: $(git -C /opt/diploma branch --show-current)"

    echo "===== DEPLOYMENT MARKER ====="
    test -s /var/lib/diploma/ansible-pull-success
    cat /var/lib/diploma/ansible-pull-success
    grep -q "^status=success$" /var/lib/diploma/ansible-pull-success

    echo "===== NGINX ====="
    nginx -t
    test "$(systemctl is-enabled nginx)" = "enabled"
    test "$(systemctl is-active nginx)" = "active"
    echo "nginx enabled: $(systemctl is-enabled nginx)"
    echo "nginx active: $(systemctl is-active nginx)"

    HTTP_CODE="$(curl -sS -o /dev/null -w "%{http_code}" http://127.0.0.1/)"
    echo "local HTTP status: ${HTTP_CODE}"
    test "$HTTP_CODE" = "200"

    echo "===== RESULT ====="
    echo "ALL CHECKS PASSED ON $(hostname)"
  '
