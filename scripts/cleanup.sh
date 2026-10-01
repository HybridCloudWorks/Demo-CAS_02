#!/usr/bin/env bash
# cleanup.sh : guest-side cleanup. Disconnect from Arc (deletes the Azure resource) and remove the demo service.
# Run inside a guest you are about to destroy. Exit 0 always-best-effort; prints what remained.
set -euo pipefail
if command -v azcmagent >/dev/null; then
  sudo azcmagent disconnect --use-device-code || echo "WARN: disconnect failed; delete the Arc resource in Azure: az connectedmachine delete -n $(hostname) -g <AZURE_RESOURCE_GROUP>"
  sudo apt-get remove -y -qq azcmagent || true
fi
sudo systemctl disable --now arc-demo-heartbeat.timer arc-demo-health.service 2>/dev/null || true
sudo rm -f /etc/systemd/system/arc-demo-*.{service,timer}; sudo rm -rf /opt/arc-demo; sudo systemctl daemon-reload
echo "Guest cleanup complete on $(hostname)."
