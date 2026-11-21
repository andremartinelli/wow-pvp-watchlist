<img src="media/icon.svg" width="96" align="right" alt="ícone do PvP Watchlist">

# PvP Watchlist

Addon para **WoW: Forever**. Marca com uma caveira quem te ataca primeiro no PvP de mundo e avisa quando essa pessoa aparece de novo.

*[English below](#english)*

## O que ele faz

- Quando um jogador inimigo te ataca, o addon marca esse jogador e guarda classe, nível, guilda, onde foi e quantas vezes ele te atacou.
- Os marcados ganham um ícone na barra de nome, com o número de ataques ao lado.
- Quando um marcado aparece de novo, você recebe um aviso: som, mensagem no chat e aviso no centro da tela. O tooltip dele também mostra o histórico.
- Não marca quem só revidou porque você atacou primeiro.
- Pode fazer um emote no atacante (`/no`, `/rude`, `/laugh`...).
- Tem botão no minimapa, entrada no menu de addons e tela de configurações em **Opções > AddOns > PvP Watchlist**.
- Funciona em português e em inglês. O idioma segue o do jogo ou pode ser escolhido nas configurações.

## Como ele descobre quem te atacou

O Forever bloqueia o registro de combate para addons (`COMBAT_LOG_EVENT_UNFILTERED`), então nenhum addon sabe quem deu cada golpe. Quando você leva um golpe ou entra em combate, o PvP Watchlist procura, por 3 segundos, jogadores inimigos por perto que estejam em combate e com você no alvo. Se o jogo esconder quem está no alvo de cada um, ele só marca quando existe um único inimigo possível.

Por isso ele pode errar ou deixar alguém passar. Para corrigir, use o link **[desmarcar]** no chat, a lista **Marcados** nas configurações ou `/pvpw marcar` com o jogador no alvo.

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
```

Cada teste termina com `TUDO OK` quando tudo passa.

## Publicação

Uma tag `v*` (por exemplo `v1.4.0`) dispara o GitHub Actions, que empacota o addon com o [BigWigs Packager](https://github.com/BigWigsMods/packager) (configuração em `.pkgmeta`) e publica no GitHub Releases e no CurseForge.

## Licença

[MIT](LICENSE). Feito por André Martinelli com a ajuda do Claude (Anthropic). Até a versão 1.3.0 o addon se chamava killonsight.

---

## English

**PvP Watchlist** is an addon for **WoW: Forever**. It marks with a skull whoever attacks you first in world PvP and warns you when that player shows up again.

- When an enemy player attacks you, the addon marks them and saves their class, level, guild, where it happened and how many times.
- Marked players get an icon on their nameplate, with the attack count next to it.
- When a marked player shows up again, you get a sound, a chat message and a warning in the middle of the screen. Their tooltip shows the history too.
- Players who only fought back because you attacked first are not marked.
- Optional emote at the attacker (`/no`, `/rude`, `/laugh`...).
- Minimap button, an entry in the AddOns menu, and a settings screen under **Options > AddOns > PvP Watchlist**.
- English and Portuguese. The language follows the game client, or you can pick one in the settings.

**How it works:** Forever blocks the combat log for addons, so no addon knows who dealt each hit. When you get hit or enter combat, PvP Watchlist looks for 3 seconds for nearby enemy players who are in combat and targeting you. If the game hides who each one is targeting, it only marks when there is exactly one possible enemy. It can miss or mismark someone; fix it with the **[unmark]** chat link, the **Marked** list in the settings, or `/pvpw mark` with the player targeted.

**Install:** search for **PvP Watchlist** in the CurseForge app or website (Forever), or download `PvPWatchlist-*.zip` from GitHub **Releases** and extract it to `World of Warcraft\_forever_\Interface\AddOns\`. Restart the game if it is open; `/reload` does not load new addons.

**Coming from killonsight (1.3.0 or older)?** Remove the `Interface\AddOns\killonsight` folder, or both will load. Your old list is in `WTF\Account\<account>\SavedVariables\killonsight.lua`: with the game closed, copy it to `PvPWatchlist.lua` in the same folder and replace `killonsightDB` with `PvPWatchlistDB` in the copy.

**Commands:** type `/pvpw` in game for the list. `/kos` works too if no other addon uses it. Every command works in English and Portuguese (see the table above).

**License:** [MIT](LICENSE). Up to version 1.3.0 the addon was called killonsight.
