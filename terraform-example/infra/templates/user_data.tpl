#!/bin/bash
set -euo pipefail

APP_DIR="/opt/fastapi-app"
APP_USER="${app_user}"
APP_PORT="${app_port}"

id -u "${APP_USER}" >/dev/null 2>&1 || useradd --home "${APP_DIR}" --system --shell /bin/bash "${APP_USER}"

mkdir -p "${APP_DIR}"
chown -R "${APP_USER}:${APP_USER}" "${APP_DIR}"

apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get install -y python3 python3-venv python3-pip git unzip

# Basic Python tooling for first boot
python3 -m venv "${APP_DIR}/.venv"
"${APP_DIR}/.venv/bin/pip" install --upgrade pip
"${APP_DIR}/.venv/bin/pip" install fastapi uvicorn[standard]
chown -R "${APP_USER}:${APP_USER}" "${APP_DIR}/.venv"

cat > "${APP_DIR}/.env" <<'EOF'
%{ for k, v in app_env ~}
${k}=${v}
%{ endfor ~}
EOF
chown "${APP_USER}:${APP_USER}" "${APP_DIR}/.env"
chmod 600 "${APP_DIR}/.env"

cat > /etc/systemd/system/fastapi.service <<EOF
[Unit]
Description=FastAPI service
After=network.target

[Service]
Type=simple
User=${app_user}
WorkingDirectory=${APP_DIR}
EnvironmentFile=${APP_DIR}/.env
ExecStart=/usr/bin/bash -lc 'cd ${APP_DIR} && if [ ! -d .venv ]; then python3 -m venv .venv; fi; if [ -f requirements.txt ]; then ./.venv/bin/pip install -r requirements.txt; fi; ./.venv/bin/uvicorn app.main:app --host 0.0.0.0 --port ${APP_PORT}'
Restart=always
RestartSec=5s
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable fastapi.service
