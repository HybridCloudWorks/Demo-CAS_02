#!/usr/bin/env bash
# configure-demo-service.sh : install the harmless demo health service without cloud-init
# (used on Hyper-V Path A after a manual Ubuntu install, or to repair a guest).
# Idempotent. Exit codes: 0 ok, 1 prerequisite missing, 2 service failed to start.
set -euo pipefail

if [[ $EUID -ne 0 ]]; then echo "ERROR: run as root (sudo)." >&2; exit 1; fi
command -v python3 >/dev/null || { echo "ERROR: python3 missing (apt-get install -y python3)" >&2; exit 1; }
command -v curl    >/dev/null || { echo "ERROR: curl missing (apt-get install -y curl)" >&2; exit 1; }

install -d -m 0755 /opt/arc-demo

cat > /opt/arc-demo/health_server.py <<'PY'
#!/usr/bin/env python3
import json, socket, time
from http.server import BaseHTTPRequestHandler, HTTPServer
START = time.time()
class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        body = json.dumps({"service": "arc-demo-health", "status": "healthy",
                           "host": socket.gethostname(), "uptime_seconds": int(time.time() - START)}).encode()
        self.send_response(200 if self.path == "/health" else 404)
        self.send_header("Content-Type", "application/json"); self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        if self.path == "/health": self.wfile.write(body)
    def log_message(self, *a): return
if __name__ == "__main__":
    HTTPServer(("127.0.0.1", 8080), Handler).serve_forever()
PY
chmod 0755 /opt/arc-demo/health_server.py

cat > /opt/arc-demo/heartbeat.sh <<'SH'
#!/usr/bin/env bash
set -euo pipefail
status="unhealthy"
if systemctl is-active --quiet arc-demo-health && curl -fsS --max-time 2 http://127.0.0.1:8080/health >/dev/null; then status="healthy"; fi
logger -t arc-demo-health -p user.notice "service=arc-demo-health status=${status} host=$(hostname)"
SH
chmod 0755 /opt/arc-demo/heartbeat.sh

cat > /etc/systemd/system/arc-demo-health.service <<'UNIT'
[Unit]
Description=Arc demo health endpoint (safe to stop; lab only)
After=network-online.target
Wants=network-online.target
[Service]
ExecStart=/usr/bin/python3 /opt/arc-demo/health_server.py
Restart=no
User=nobody
Group=nogroup
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
PrivateTmp=true
[Install]
WantedBy=multi-user.target
UNIT

cat > /etc/systemd/system/arc-demo-heartbeat.service <<'UNIT'
[Unit]
Description=Arc demo heartbeat: writes health state to syslog
[Service]
Type=oneshot
ExecStart=/opt/arc-demo/heartbeat.sh
UNIT

cat > /etc/systemd/system/arc-demo-heartbeat.timer <<'UNIT'
[Unit]
Description=Run arc-demo-heartbeat every minute
[Timer]
OnBootSec=1min
OnUnitActiveSec=1min
AccuracySec=5s
[Install]
WantedBy=timers.target
UNIT

systemctl daemon-reload
systemctl enable --now arc-demo-health.service
systemctl enable --now arc-demo-heartbeat.timer
sleep 2
if curl -fsS --max-time 3 http://127.0.0.1:8080/health; then
  echo; echo "OK: arc-demo-health is serving on 127.0.0.1:8080"
else
  echo "ERROR: service did not respond. journalctl -u arc-demo-health" >&2; exit 2
fi
