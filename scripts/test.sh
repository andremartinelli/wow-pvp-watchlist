#!/usr/bin/env bash
# Runs every test in the tests folder with Lua 5.1 (or the one in the LUA variable).
# A test passes only if it exits without error and its last line is "ALL OK";
# the script exits with code 1 if any test fails, so it works in CI and in cloud sessions.
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
  if [ "$code" -eq 0 ] && [ "$last" = "ALL OK" ]; then
    echo "OK     $t"
  else
    echo "FALHOU $t (codigo $code, ultima linha: $last)"
    printf '%s\n' "$out" | grep -E '^FAIL' || printf '%s\n' "$out" | tail -n 15
    failed=1
  fi
done

if [ "$failed" -eq 0 ]; then echo "test: todos os testes passaram"; else echo "test: houve falhas"; fi
exit "$failed"
