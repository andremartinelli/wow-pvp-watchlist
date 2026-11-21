<img src="media/icon.svg" width="96" align="right" alt="ícone do killonsight">

# killonsight

Addon para **WoW: Forever**. Marca com uma caveira quem te ataca primeiro no PvP de mundo e avisa quando essa pessoa aparece de novo.

*[English below](#english)*

## O que ele faz

- Quando um jogador inimigo te ataca, o addon marca esse jogador e guarda classe, nível, guilda, onde foi e quantas vezes ele te atacou.
- Os marcados ganham um ícone na barra de nome, com o número de ataques ao lado.
- Quando um marcado aparece de novo, você recebe um aviso: som, mensagem no chat e aviso no centro da tela. O tooltip dele também mostra o histórico.
- Não marca quem só revidou porque você atacou primeiro.
- Pode fazer um emote no atacante (`/no`, `/rude`, `/laugh`...).
- Tem botão no minimapa, entrada no menu de addons e tela de configurações em **Opções > AddOns > killonsight**.
- Funciona em português e em inglês. O idioma segue o do jogo ou pode ser escolhido nas configurações.

## Como ele descobre quem te atacou

O Forever bloqueia o registro de combate para addons (`COMBAT_LOG_EVENT_UNFILTERED`), então nenhum addon sabe quem deu cada golpe. Quando você leva um golpe ou entra em combate, o killonsight procura, por 3 segundos, jogadores inimigos por perto que estejam em combate e com você no alvo. Se o jogo esconder quem está no alvo de cada um, ele só marca quando existe um único inimigo possível.

Por isso ele pode errar ou deixar alguém passar. Para corrigir, use o link **[desmarcar]** no chat, a lista **Marcados** nas configurações ou `/kos marcar` com o jogador no alvo.

## Instalação

1. Baixe o ZIP pelo botão **Code > Download ZIP**.
2. Extraia em `World of Warcraft\_forever_\Interface\AddOns\`.
3. Renomeie a pasta `killonsight-main` para `killonsight`.
4. Abra o jogo, ou dê `/reload` se ele já estiver aberto.

## Comandos

Todos os comandos funcionam em português e em inglês.

| Comando | Em inglês | O que faz |
|---|---|---|
| `/kos` | | Mostra a ajuda |
| `/kos config` | `/kos options` | Abre as configurações |
| `/kos lista` | `/kos list` | Lista os marcados, com link para desmarcar |
| `/kos marcar` | `/kos mark` | Marca o seu alvo à mão |
| `/kos tirar` | `/kos remove` | Desmarca o seu alvo |
| `/kos apagar Nome` | `/kos delete Name` | Desmarca pelo nome |
| `/kos som` | `/kos sound` | Liga ou desliga o som |
| `/kos mensagem` | `/kos message` | Liga ou desliga a mensagem de aviso |
| `/kos emote` | `/kos emote` | Liga ou desliga o emote |
| `/kos minimapa` | `/kos minimap` | Mostra ou esconde o botão no minimapa |
| `/kos idioma auto, pt ou en` | `/kos language auto, pt or en` | Muda o idioma do addon |
| `/kos teste` | `/kos test` | Adversário de duelo conta como inimigo, para testar |
| `/kos debug` | `/kos debug` | Mostra no chat o que o addon está vendo |

**Botão do minimapa:** clique para abrir as configurações, clique com o botão direito para ligar ou desligar a marcação automática, arraste para mudar de lugar.

## Testes

A pasta `tests` simula a API do jogo para testar o addon fora dele. Rode da pasta principal com Lua 5.1 a 5.4:

```
lua tests/test_kos.lua
lua tests/test_kos2.lua
lua tests/test_kos3.lua
```

Cada teste termina com `TUDO OK` quando tudo passa.

## Licença

[MIT](LICENSE). Feito por André Martinelli com a ajuda do Claude (Anthropic).

---

## English

**killonsight** is an addon for **WoW: Forever**. It marks with a skull whoever attacks you first in world PvP and warns you when that player shows up again.

- When an enemy player attacks you, the addon marks them and saves their class, level, guild, where it happened and how many times.
- Marked players get an icon on their nameplate, with the attack count next to it.
- When a marked player shows up again, you get a sound, a chat message and a warning in the middle of the screen. Their tooltip shows the history too.
- Players who only fought back because you attacked first are not marked.
- Optional emote at the attacker (`/no`, `/rude`, `/laugh`...).
- Minimap button, an entry in the AddOns menu, and a settings screen under **Options > AddOns > killonsight**.
- English and Portuguese. The language follows the game client, or you can pick one in the settings.

**How it works:** Forever blocks the combat log for addons, so no addon knows who dealt each hit. When you get hit or enter combat, killonsight looks for 3 seconds for nearby enemy players who are in combat and targeting you. If the game hides who each one is targeting, it only marks when there is exactly one possible enemy. It can miss or mismark someone; fix it with the **[unmark]** chat link, the **Marked** list in the settings, or `/kos mark` with the player targeted.

**Install:** download the ZIP (**Code > Download ZIP**), extract it to `World of Warcraft\_forever_\Interface\AddOns\` and rename the `killonsight-main` folder to `killonsight`.

**Commands:** type `/kos` in game for the list. Every command works in English and Portuguese (see the table above).

**License:** [MIT](LICENSE).
