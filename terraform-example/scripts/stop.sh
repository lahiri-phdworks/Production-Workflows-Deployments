#!/usr/bin/env bash
set -euo pipefail

systemctl stop fastapi.service || true
