# PvP Watchlist: instruções para o Claude

Addon de WoW: Forever em Lua 5.1 (a versão do jogo). O `.toc` carrega `Locales.lua`, `PvPWatchlist.lua` e `Share.lua`. Os testes na pasta `tests` simulam a API do jogo.

## Preparar e testar

- `bash scripts/cloud-setup.sh` instala o Lua 5.1 pelo apt. É idempotente; rode se `lua5.1` não existir.
- `bash scripts/test.sh` roda os quatro testes e termina com erro se algum não chegar ao `TUDO OK`. Rode antes de todo commit que mexe no addon.
- Não há banco, serviços, `.env` nem segredos de desenvolvimento.
- Todo texto novo do addon entra em português e em inglês no `Locales.lua` (o `test_kos4.lua` confere).
- Arquivo novo que não faz parte do addon (script, documentação) entra no `ignore` do `.pkgmeta`, senão vai para o zip publicado.

## Publicação (produção)

- Uma tag `v*` dispara `.github/workflows/release.yml`, que publica no GitHub Releases e no CurseForge. Nunca crie nem envie tag, nem rode o packager com envio.
- `CF_API_KEY` e `GITHUB_TOKEN` são segredos do CI. Nunca peça, imprima nem grave esses valores.
- Sem merge: abra o PR e pare.
