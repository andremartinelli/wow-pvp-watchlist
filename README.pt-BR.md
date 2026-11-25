<img src="media/icon.svg" width="96" align="right" alt="ícone do PvP Watchlist">

# PvP Watchlist

Addon para **WoW: Forever**. Marca com uma caveira quem te ataca primeiro no PvP de mundo e avisa quando essa pessoa aparece de novo.

[English](README.md) | **Português**

## O que ele faz

- Quando um jogador inimigo te ataca, o addon marca esse jogador e guarda classe, nível, guilda, onde foi e quantas vezes ele te atacou.
- Os marcados ganham um ícone na barra de nome, com o número de ataques ao lado.
- Quando um marcado aparece de novo, você recebe um aviso: som, mensagem no chat e aviso no centro da tela. O tooltip dele também mostra o histórico.
- Não marca quem só revidou porque você atacou primeiro.
- Troca a lista com os amigos e com a guilda que também usam o addon. Cada lista (a sua, a dos amigos e a da guilda) tem o ícone que você escolher nas configurações, e pode ser o mesmo para todas. O padrão é caveira para a sua, X para amigos e triângulo para a guilda.
- Pode fazer um emote no atacante (`/no`, `/rude`, `/laugh`...).
- Tem botão no minimapa, entrada no menu de addons e tela de configurações em **Opções > AddOns > PvP Watchlist**.
- Funciona em português e em inglês. O idioma segue o do jogo ou pode ser escolhido nas configurações.

## Como ele descobre quem te atacou

O Forever bloqueia o registro de combate para addons (`COMBAT_LOG_EVENT_UNFILTERED`), então nenhum addon sabe quem deu cada golpe. Quando você leva um golpe ou entra em combate, o PvP Watchlist procura, por 3 segundos, jogadores inimigos por perto que estejam em combate e com você no alvo. Se o jogo esconder quem está no alvo de cada um, ele só marca quando existe um único inimigo possível.

Por isso ele pode errar ou deixar alguém passar. Para corrigir, use o link **[desmarcar]** no chat, a lista **Marcados** nas configurações ou `/pvpw marcar` com o jogador no alvo.

## Compartilhamento com amigos e guilda

- A troca usa mensagens de addon, que não aparecem no chat de ninguém. Quem recebe precisa ter o PvP Watchlist 1.5.0 ou mais novo.
- Vão só as suas marcações confiáveis: o atacante estava com você no alvo, ou você marcou à mão. O que você recebeu de outros não é repassado.
- Só são aceitas mensagens de quem está na sua guilda ou na sua lista de amigos (e do Battle.net, se ligado nas configurações).
- O jogo bloqueia mensagens de addon em masmorras, raides e campos de batalha. Fora deles, a fila espera você sair de combate e manda uma mensagem por segundo.
- Quando um marcado por amigos ou guilda aparece, vem uma mensagem no chat dizendo quem marcou, sem som. O link **[ocultar]** esconde esse jogador até ele ser marcado de novo. `/pvpw bloquear Nome` apaga e passa a ignorar as marcações de alguém.
- Uma marcação recebida some depois de 30 dias sem novidade.
- Nas configurações, a seção **Compartilhamento** liga ou desliga guilda, amigos e Battle.net (os dois primeiros vêm ligados). A página **Marcados** tem um filtro: minha lista, amigos ou guilda.

## Instalação

- **CurseForge:** procure **PvP Watchlist** no app ou no site do CurseForge (versão Forever).
- **GitHub:** baixe o `PvPWatchlist-*.zip` em **Releases** e extraia em `World of Warcraft\_forever_\Interface\AddOns\`. A pasta já vem com o nome certo, `PvPWatchlist`.

Depois abra o jogo. Se ele já estiver aberto, feche e abra de novo: o `/reload` não carrega addons novos.

**Vindo do killonsight (1.3.0 ou antes)?** Tire a pasta `Interface\AddOns\killonsight`, senão os dois carregam juntos. A lista antiga fica em `WTF\Account\<conta>\SavedVariables\killonsight.lua`: com o jogo fechado, copie para `PvPWatchlist.lua` na mesma pasta e troque `killonsightDB` por `PvPWatchlistDB` na cópia.

## Comandos

Todos os comandos funcionam em português e em inglês. `/kos` também funciona, se nenhum outro addon usar esse comando.

| Comando | Em inglês | O que faz |
|---|---|---|
| `/pvpw` | | Mostra a ajuda |
| `/pvpw config` | `/pvpw options` | Abre as configurações |
| `/pvpw lista` | `/pvpw list` | Lista os marcados, com link para desmarcar |
| `/pvpw lista amigos` ou `guilda` | `/pvpw list friends` or `guild` | Lista os marcados por amigos ou pela guilda |
| `/pvpw compartilhar` | `/pvpw share` | Manda a sua lista para amigos e guilda agora |
| `/pvpw bloquear Nome` | `/pvpw block Name` | Apaga e passa a ignorar as marcações de alguém |
| `/pvpw desbloquear Nome` | `/pvpw unblock Name` | Volta a aceitar as marcações dessa pessoa |
| `/pvpw marcar` | `/pvpw mark` | Marca o seu alvo à mão |
| `/pvpw tirar` | `/pvpw remove` | Desmarca o seu alvo |
| `/pvpw apagar Nome` | `/pvpw delete Name` | Desmarca pelo nome |
| `/pvpw som` | `/pvpw sound` | Liga ou desliga o som |
| `/pvpw mensagem` | `/pvpw message` | Liga ou desliga a mensagem de aviso |
| `/pvpw emote` | `/pvpw emote` | Liga ou desliga o emote |
| `/pvpw minimapa` | `/pvpw minimap` | Mostra ou esconde o botão no minimapa |
| `/pvpw idioma auto, pt ou en` | `/pvpw language auto, pt or en` | Muda o idioma do addon |
| `/pvpw teste` | `/pvpw test` | Adversário de duelo conta como inimigo, para testar |
| `/pvpw debug` | `/pvpw debug` | Mostra no chat o que o addon está vendo |

**Botão do minimapa:** clique para abrir as configurações, clique com o botão direito para ligar ou desligar a marcação automática, arraste para mudar de lugar.

## Testes

A pasta `tests` simula a API do jogo para testar o addon fora dele. Rode da pasta principal com Lua 5.1 a 5.4:

```
lua tests/test_kos.lua
lua tests/test_kos2.lua
lua tests/test_kos3.lua
lua tests/test_kos4.lua
```

O 4 cobre o compartilhamento com amigos, guilda e Battle.net.

Cada teste termina com `TUDO OK` quando tudo passa.

**No Linux e nas sessões na nuvem do Claude Code:** `bash scripts/cloud-setup.sh` instala o Lua 5.1 (a versão do WoW) pelo apt e pode rodar quantas vezes quiser. Depois, `bash scripts/test.sh` roda os quatro testes e termina com erro se algum não chegar ao `TUDO OK`. O addon não tem banco, serviços nem `.env`, então não há mais nada a preparar.

## Publicação

Uma tag `v*` (por exemplo `v1.4.0`) dispara o GitHub Actions, que empacota o addon com o [BigWigs Packager](https://github.com/BigWigsMods/packager) (configuração em `.pkgmeta`) e publica no GitHub Releases e no CurseForge.

## Licença

[MIT](LICENSE). Feito por André Martinelli com a ajuda do Claude (Anthropic). Até a versão 1.3.0 o addon se chamava killonsight.

