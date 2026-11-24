#!/usr/bin/env bash
# Prepara um Linux Debian/Ubuntu (como as sessoes na nuvem do Claude Code) para rodar os testes do addon.
# Idempotente e nao interativo: pode rodar quantas vezes quiser, de qualquer pasta.
# O addon nao tem banco, servicos nem .env: so precisa do Lua 5.1, a mesma versao que o WoW usa.
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
