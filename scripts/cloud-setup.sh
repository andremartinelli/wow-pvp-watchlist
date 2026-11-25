#!/usr/bin/env bash
# Prepares a Debian/Ubuntu Linux (like the Claude Code cloud sessions) to run the addon tests.
# Idempotent and non-interactive: safe to run any number of times, from any folder.
# The addon has no database, services or .env: it only needs Lua 5.1, the same version WoW uses.
set -euo pipefail

cd "$(dirname "$0")/.."

if command -v lua5.1 >/dev/null 2>&1; then
  echo "cloud-setup: Lua 5.1 ja instalado ($(lua5.1 -v 2>&1))"
else
  SUDO=""
  if [ "$(id -u)" -ne 0 ]; then SUDO="sudo -n"; fi
  export DEBIAN_FRONTEND=noninteractive
  echo "cloud-setup: instalando o Lua 5.1 pelo apt"
  $SUDO apt-get update -qq
  $SUDO apt-get install -y -qq --no-install-recommends lua5.1 >/dev/null
  echo "cloud-setup: $(lua5.1 -v 2>&1) instalado"
fi

echo "cloud-setup: pronto. Rode os testes com: bash scripts/test.sh"
