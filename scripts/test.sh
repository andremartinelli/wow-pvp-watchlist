#!/usr/bin/env bash
# Roda todos os testes da pasta tests com o Lua 5.1 (ou o da variavel LUA).
# Cada teste so passa se sair sem erro e a ultima linha for "TUDO OK";
# o script termina com codigo 1 se algum falhar, para servir em CI e nas sessoes na nuvem.
set -uo pipefail

cd "$(dirname "$0")/.."

LUA="${LUA:-$(command -v lua5.1 || command -v lua || true)}"
if [ -z "$LUA" ]; then
  echo "test: Lua nao encontrado. Rode antes: bash scripts/cloud-setup.sh" >&2
  exit 1
fi
echo "test: usando $("$LUA" -v 2>&1)"

failed=0
for t in tests/test_*.lua; do
  out="$("$LUA" "$t" 2>&1)"
  code=$?
  last="$(printf '%s\n' "$out" | tail -n 1)"
  if [ "$code" -eq 0 ] && [ "$last" = "TUDO OK" ]; then
    echo "OK     $t"
  else
    echo "FALHOU $t (codigo $code, ultima linha: $last)"
    printf '%s\n' "$out" | grep -E '^FALHA' || printf '%s\n' "$out" | tail -n 15
    failed=1
  fi
done

if [ "$failed" -eq 0 ]; then echo "test: todos os testes passaram"; else echo "test: houve falhas"; fi
exit "$failed"
