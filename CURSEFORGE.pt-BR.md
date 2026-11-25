# PvP Watchlist no CurseForge

[English](CURSEFORGE.md) | **Português**

Tradução do `CURSEFORGE.md`, para consulta. A página do projeto no CurseForge usa o texto em inglês. Este arquivo não vai no pacote.

- Jogo: World of Warcraft, tipo **Forever**, versão do jogo **1.60.1** (Interface 16001)
- Nome: PvP Watchlist (pasta `PvPWatchlist`)
- Licença: MIT
- Código: https://github.com/andremartinelli/wow-pvp-watchlist

## Resumo

Marca sozinho quem te ataca primeiro no PvP de mundo e mostra nas suas barras de nome os jogadores que a sua guilda e os seus amigos marcaram.

## Descrição

No CurseForge vai o texto em inglês entre as linhas do `CURSEFORGE.md`. Abaixo, a tradução dele.

---

O **PvP Watchlist** monta a sua lista de *kill on sight* (matar assim que ver) por você. Quem te ataca primeiro no PvP de mundo é marcado sozinho, sem nenhum clique, e os jogadores que a sua guilda e os seus amigos marcaram aparecem nas suas barras de nome. Feito para o **WoW: Forever**.

### Por que o PvP Watchlist

- **Sem cliques.** No momento em que um jogador inimigo te ataca, ele entra na sua lista, mesmo que você sobreviva à luta. Quem só revidou porque você atacou primeiro fica de fora.
- **A lista da guilda na sua tela.** Jogadores marcados por colegas de guilda e amigos que também usam o PvP Watchlist ganham um ícone próprio na barra de nome e um aviso no chat quando aparecem, então você vê quem anda caçando a sua guilda antes de ele chegar em você.

### O que ele faz

- Cada marcado fica salvo com classe, nível, guilda, onde foi e quantas vezes te atacou.
- Um ícone de raide na barra de nome, com o número de ataques ao lado. A sua lista, a dos amigos e a da guilda usam o ícone que você escolher nas configurações (caveira, X e triângulo no padrão), e pode ser o mesmo para todas.
- Quando um marcado aparece de novo (barra de nome, alvo ou mouse em cima), você recebe som, mensagem no chat e aviso no centro da tela, no máximo uma vez a cada 5 minutos por jogador. O tooltip dele também mostra o histórico.
- Emote opcional no atacante quando ele é marcado (`/no` no padrão). Dá para escolher outro ou desligar.
- Botão no minimapa, entrada no menu de addons ao lado do minimapa e tela de configurações.
- Não precisa de bibliotecas nem de outros addons.

### Como funciona, e os limites do Forever

O WoW: Forever bloqueia o registro de combate para addons (`COMBAT_LOG_EVENT_UNFILTERED`), então nenhum addon sabe quem deu cada golpe, e algumas informações dos jogadores ficam escondidas dos addons durante o combate.

Quando você leva um golpe ou entra em combate, o PvP Watchlist procura, por 3 segundos, jogadores inimigos por perto (barras de nome, alvo, foco e mouse em cima) que estejam em combate e com você no alvo. Se o jogo esconder quem está no alvo de cada um, ele só marca quando existe um único inimigo possível. Ele não procura atacantes dentro de masmorras, raides ou campos de batalha.

Por isso ele pode deixar um atacante passar ou marcar o jogador errado. Para corrigir, use o link **[desmarcar]** no chat, a lista **Marcados** nas configurações ou `/pvpw marcar` com o jogador no alvo.

Fora o emote opcional, ele nunca faz nada no jogo por você: só observa e avisa.

### Compartilhamento com amigos e guilda

- Usa mensagens de addon, que não aparecem no chat de ninguém. Quem recebe precisa do PvP Watchlist 1.5.0 ou mais novo.
- Vão só as suas marcações confiáveis: o atacante estava com você no alvo, ou você marcou à mão. O que você recebeu de outros nunca é repassado.
- Só são aceitas mensagens da sua guilda, da sua lista de amigos e, se você ligar, dos seus amigos do Battle.net. Mensagens de desconhecidos são ignoradas.
- O jogo bloqueia mensagens de addon em masmorras, raides e campos de batalha, então o compartilhamento funciona no mundo aberto. As mensagens esperam você sair de combate e vão uma por segundo.
- Quando aparece um jogador marcado por um amigo ou colega de guilda, vem uma mensagem no chat dizendo quem marcou, sem som. O link **[ocultar]** esconde esse jogador até ele ser marcado de novo, e `/pvpw bloquear Nome` apaga e passa a ignorar as marcações de alguém.
- Marcações recebidas somem depois de 30 dias sem novidade.

### Comandos

`/kos` também funciona como atalho, se nenhum outro addon usar esse comando. Todos os comandos também funcionam em inglês.

| Comando | O que faz |
|---|---|
| `/pvpw` | Mostra a ajuda |
| `/pvpw config` | Abre as configurações |
| `/pvpw lista` | Lista os marcados, com link para desmarcar cada um |
| `/pvpw lista amigos` ou `guilda` | Lista os marcados pelos seus amigos ou pela sua guilda |
| `/pvpw compartilhar` | Manda a sua lista para amigos e guilda agora |
| `/pvpw bloquear Nome` | Apaga e passa a ignorar as marcações de alguém |
| `/pvpw desbloquear Nome` | Volta a aceitar as marcações dessa pessoa |
| `/pvpw marcar` | Marca o seu alvo à mão |
| `/pvpw tirar` | Desmarca o seu alvo |
| `/pvpw apagar Nome` | Desmarca um jogador pelo nome |
| `/pvpw som`, `mensagem`, `emote` | Liga ou desliga o som, a mensagem de aviso ou o emote |
| `/pvpw minimapa` | Mostra ou esconde o botão no minimapa |
| `/pvpw idioma auto`, `pt` ou `en` | Muda o idioma do addon |
| `/pvpw teste` | Adversário de duelo conta como inimigo, para testar |
| `/pvpw debug` | Mostra no chat o que o addon está vendo |

**Botão do minimapa:** clique para abrir as configurações, clique com o botão direito para ligar ou desligar a marcação automática, arraste para mudar de lugar.

### Configurações

Abra em **Opções > AddOns > PvP Watchlist**, ou digite `/pvpw config`.

- **Detecção:** marcação automática ligada ou desligada; não marcar quem você atacou primeiro, e por quanto tempo lembrar do seu ataque; ignorar jogadores muito abaixo do seu nível.
- **Reação:** o emote no atacante, e qual (`/no`, `/rude`, `/laugh`, `/chicken`, `/spit` ou `/point`).
- **Marcador na barra de nome:** qual ícone de raide para a sua lista, para os marcados por amigos e para os marcados pela guilda (podem ser o mesmo), o tamanho dele e se mostra o número de ataques.
- **Avisos:** som (três opções, com botão de testar), mensagem no chat, aviso grande na tela e a linha no tooltip do jogador.
- **Interface:** botão no minimapa e idioma.
- **Compartilhamento:** trocar com a sua guilda e com a sua lista de amigos (os dois ligados no padrão) e com amigos do Battle.net (desligado no padrão); aviso no chat para os marcados por eles e, se quiser, o aviso grande na tela também.
- **Marcados:** uma subpágina com todos os marcados, do mais recente, com filtro por minha lista, amigos ou guilda, e um botão Desmarcar ou Ocultar em cada um.

### Idiomas

Inglês e português do Brasil. O addon segue o idioma do jogo (cliente em português recebe português, todos os outros recebem inglês), ou você escolhe um idioma nas configurações ou com `/pvpw idioma`.

### Código e relato de erros

https://github.com/andremartinelli/wow-pvp-watchlist (licença MIT). Até a versão 1.3.0 o addon se chamava killonsight e só estava no GitHub.

---

## Categorias

Os nomes são os do CurseForge, em inglês.

- Principal: **PvP**
- Extras (até 4): **Guild** (compartilhamento com a guilda), **Combat**, **Unit Frames** (o marcador na barra de nome), **Tooltip**
