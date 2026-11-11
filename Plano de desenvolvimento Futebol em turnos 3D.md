# Plano de desenvolvimento: Futebol em turnos 3D

Nov 11, 2026 · @Blue

## Visão e decisões de design

O jogo é um futebol 3D em turnos simultâneos: nos 30 segundos de planejamento cada jogador escolhe a ação do seu atleta, e quando o tempo acaba tudo acontece de uma vez, como em Your Only Move Is HUSTLE. As decisões abaixo são propostas minhas para o MVP; troque o que não combinar com a sua ideia.

- **Turnos simultâneos, não alternados.** Os dois escolhem e confirmam, e então o jogo segue. A graça está na leitura: ao escolher uma ação, aparece um espectro translúcido do que vai acontecer (movimento e trajetória), e você vê também todos os movimentos possíveis do adversário, cujos espectros se cruzam com o seu na tela. Saber ler essas opções é o que separa quem joga bem de quem não joga.
- **Execução determinística por ticks.** Cada ação custa um número de ticks (frames), como no Your Only Move Is HUSTLE. Depois que os dois confirmam, a simulação roda sem input até a ação de alguém terminar. Aí ela pausa e quem ficou livre escolhe de novo, enquanto a ação do outro continua. Se a sua ação dura 15 ticks e a dele 6, ele pode agir duas vezes no tempo da sua. Poder tem custo: ações mais pesadas gastam mais ticks e deixam você preso até terminarem. Quem salta precisa esperar cair para agir de novo, enquanto quem está no chão pode chutar antes. Pensar antes de agir é o coração do jogo.
- **A bola é o centro do 3D.** O chute tem direção, força, efeito lateral e elevação, para curvar, subir e descer.
- **Câmera isométrica ortográfica.** O estilo anime (cel shading e contorno) só entra depois que a jogabilidade estiver divertida em cinza.
- **Escopo do MVP:** começa em 1 contra 1 contra a IA. O 3 contra 3 existe só online, com cada pessoa controlando um jogador e no máximo 3 por lado. O goleiro de cada time é controlado por IA, além dos 3 jogadores. Um campo, dois tempos curtos.

## Como usar a IA com a cota de 20 por dia

Gaste a requisição do agente só no que exige mexer em vários arquivos ou rodar o Godot, e faça o resto no chat gratuito e no editor. O valor de 20 requisições por dia vem de um tutorial de julho de 2026 e pode ter mudado; não sei se cada chamada de ferramenta do agente conta separado, então meça no primeiro dia.

| Ferramenta | Use para | Custo na cota |
| --- | --- | --- |
| Chat gratuito do Claude | Escrever e revisar scripts GDScript, planejar sistemas, explicar erros colados | Nenhum |
| Agente do Antigravity (com Godot MCP) | Criar cenas e vários arquivos de uma vez, rodar o projeto e ler os erros | 1 ou mais por pedido |
| Editor do Godot | Posicionar objetos, ajustar números, testar, definir a cena principal | Nenhum |
| Git | Salvar uma versão antes de cada pedido ao agente, para poder desfazer | Nenhum |

Regras de trabalho:

1. Um pedido grande e bem especificado por fase, em vez de vários pequenos.
2. Faça um commit no Git antes de cada pedido ao agente.
3. Peça no mesmo pedido que o agente rode o projeto e relate os erros.
4. Quando a cota acabar, continue pelo chat e pelo editor, colando o código você mesmo.

## Ferramentas

Você já tem o essencial funcionando: Godot 4.7.2, o Antigravity e o Godot MCP. O resto entra só quando a fase correspondente chegar.

| Função | Ferramenta | Quando entra |
| --- | --- | --- |
| Engine | Godot 4.7.2 com GDScript | Já instalado |
| Agente de código | Antigravity com o Godot MCP | Já configurado e testado |
| Apoio e revisão de código | Chat gratuito do Claude | Desde o início |
| Controle de versão | Git local (GitHub opcional) | Antes do primeiro pedido ao agente |
| Modelos 3D | Blender, ou Meshy e Tripo para modelos gerados por IA | Fase de arte |
| Estilo anime | Shader de cel shading e contorno no próprio Godot | Fase de arte |
| Áudio | ElevenLabs (voz e efeitos) e Suno (música) | Fase de polimento |

Antes de usar qualquer asset gerado por IA em um jogo que você pretende publicar, confira a licença comercial da ferramenta.

## Arquitetura: planejar, congelar, simular

O jogo alterna duas fases, e só a segunda mexe no mundo: o planejamento coleta as ações, e a execução as aplica por um número fixo de ticks.

- **Ações como dados.** Cada ação (mover, chutar) é um pequeno objeto com tipo, alvo, força e efeitos. A interface só preenche esses dados e a simulação os lê.
- **Passo fixo.** A execução avança tick a tick (1/60 s), sempre com o mesmo passo e sem depender do tempo entre quadros, para o resultado ser reproduzível. Cada ação tem uma duração em ticks, e a simulação para quando alguma delas termina.
- **Física da bola própria.** A bola é um estado (posição, velocidade, rotação) integrado por código seu, com gravidade, arrasto e força de Magnus, a força que curva uma bola que gira. Isso dá controle total sobre curvas, subidas e descidas.
- **Repetição de graça.** Como a execução depende só do estado inicial e das ações, dá para guardar e rever qualquer lance. O espectro de cada ação, mostrado no planejamento, é a mesma simulação rodada numa cópia do estado, sem alterar o jogo. Para mostrar todas as opções do adversário, o jogo lista as ações possíveis de cada jogador a partir do estado e simula cada uma numa cópia; onde há valores contínuos (direção, força), mostra uma zona em vez de cada trajetória.
- **IA do adversário.** Escolhe suas ações na fase de planejamento, usando as mesmas estruturas de ação do jogador.

&#91;embedded content: ciclo do turno · 4 etapas\]

Quando o tempo acaba ou o jogador confirma, as ações são congeladas e a execução roda sem nenhum input.

## Roadmap por fases

Cada fase termina com algo jogável e um critério claro para passar à seguinte. Planeje cada fase como um pedido grande ao agente, mais ajustes pelo chat e pelo editor.

&#91;embedded content: roadmap · 4 fases, 4 critérios\]

A fase 1 é o protótipo cinza descrito abaixo; as outras só começam depois que o critério da anterior for cumprido.

## Primeiro protótipo (cinza)

O protótipo prova uma coisa só: dá para planejar uma ação em 30 segundos, executá-la sem input e ver a bola curvar em 3D. Sem arte, sem IA do adversário e sem menus.

**O que entra:**

- Campo plano com linhas e dois gols feitos de caixas, câmera ortográfica isométrica (giro de 45° em Y, inclinação de cerca de 35° em X).
- Um jogador controlável (cápsula azul), um adversário (cápsula vermelha) e a bola (esfera). O adversário tem 5 ações fixas (ficar parado, avançar na bola, recuar para o gol, desviar para a esquerda, desviar para a direita), todas visíveis como espectros, e executa uma de cada vez, em rodízio: quando termina uma, passa à seguinte.
- Fase de planejamento com contagem de 30 s e botão Confirmar. Deixe o tempo configurável e use 10 s nos testes.
- Duas ações: Mover (clicar no campo) e Chutar (direção, força, efeito lateral, efeito vertical e elevação por controles deslizantes). Enquanto o jogador ajusta, um espectro azul translúcido mostra o movimento dele e a trajetória da bola, calculados pela mesma simulação numa cópia do estado. Os espectros das 5 ações possíveis do adversário aparecem em vermelho translúcido, sobrepostos aos seus.
- Fase de execução tick a tick a 60 Hz, com a câmera acompanhando a bola. Cada ação tem uma duração em ticks (valores iniciais, ajustáveis: ficar parado 10, chutar 20, desviar 20, avançar ou recuar 30, e mover conforme a distância, até 60). A execução pausa quando a ação de alguém termina: quem ficou livre escolhe de novo, e a ação do outro continua. Quem usa uma ação mais pesada fica preso por mais ticks, e o outro pode agir de novo nesse intervalo.
- Física própria da bola: gravidade, arrasto do ar, quique no chão e efeito.
- Gol reinicia a bola e soma no placar.

**Critérios de pronto:**

1. O projeto roda com F5 sem erros.
2. Quando o tempo acaba (ou ao confirmar), a execução começa sozinha.
3. A mesma ação com os mesmos valores dá exatamente o mesmo resultado em duas execuções seguidas, e o espectro do planejamento coincide com o que acontece na execução.
4. Efeito lateral positivo e negativo curvam a bola para lados opostos, e elevação alta faz a bola subir e cair.

**Fica de fora:** IA de verdade para o adversário, vários jogadores, saltar e cabecear (a ação pesada do exemplo, que entra na fase 2), arte anime, som, multiplayer.

## Prompt pronto para o Antigravity

Cole este texto numa conversa do Antigravity aberta dentro do projeto your-only-move-is-pass (não em "No Project"). Ele foi escrito para o agente fazer tudo numa requisição só e se corrigir sozinho com o Godot MCP. Faça um commit no Git antes de enviar.

```text
Você é meu agente de desenvolvimento neste projeto Godot 4.7 (pasta your-only-move-is-pass). Use o MCP "godot". Faça tudo neste único pedido, sem me fazer perguntas: se algo for ambíguo, escolha a opção mais simples e anote a escolha em NOTAS.md.

OBJETIVO: protótipo cinza (sem arte) de um jogo de futebol 3D em turnos simultâneos. Cada turno tem uma fase de planejamento (contagem regressiva) e uma fase de execução (simulação determinística tick a tick, que para quando a ação de alguém termina).

1) ESTRUTURA DE ARQUIVOS
- scenes/main.tscn (defina como cena principal em project.godot)
- scripts/game.gd (máquina de estados PLANNING -> EXECUTING -> PLANNING, placar)
- scripts/ball.gd, scripts/player.gd, scripts/ui.gd
- NOTAS.md (decisões tomadas e o que falta)

2) CENA 3D
- Campo plano de 40 x 24 m com linhas simples e dois gols (caixas) nas extremidades menores.
- Camera3D ortográfica (size cerca de 30), rotação Y de 45 graus e X de -35.264 graus, olhando para o centro do campo.
- Jogador azul (cápsula) à esquerda, adversário vermelho (cápsula) à direita, bola (esfera de raio 0.22). Uma luz direcional.

3) FASES DO TURNO
- PLANNING: contagem regressiva visível, variável exportada planning_seconds (padrão 30). Botão Confirmar encerra antes. Ao chegar a zero, a execução começa sozinha.
- Na PLANNING o jogador escolhe UMA ação:
  a) MOVER: clicar no campo define o destino (raio da câmera contra o plano y=0). Na execução o jogador corre até lá a 6 m/s.
  b) CHUTAR: sliders de direção (-90 a 90 graus, relativa ao gol adversário), força (0 a 30 m/s), elevação (0 a 45 graus), efeito lateral (-1 a 1) e efeito vertical (-1 a 1, topspin/backspin). Se a bola estiver a mais de 1.5 m do jogador, o chute falha e mostra a mensagem "longe demais".
- ESPECTRO (ghost): enquanto o jogador ajusta a ação, mostre um espectro azul translúcido do que VAI acontecer: o caminho do jogador e a trajetória da bola (por exemplo, cópias translúcidas da cápsula e da bola a cada 10 ticks, mais uma linha). Calcule rodando a MESMA simulação, até essa ação terminar, numa cópia do estado, sem alterar o jogo real, e atualize a cada mudança de valor.
- ADVERSÁRIO: tem 5 ações fixas (ficar parado, avançar na bola, recuar para o gol, desviar para a esquerda, desviar para a direita). Mostre o espectro de TODAS elas em vermelho translúcido, sobreposto ao espectro do jogador. Na execução ele faz uma delas de cada vez, em rodízio (1ª, 2ª, 3ª, 4ª, 5ª, 1ª...), e escolhe a seguinte quando a atual termina.
- EXECUTING: simula tick a tick com passo fixo constante de 1/60 s (nada de delta variável), sem input. Cada ação tem uma duração em ticks (variáveis exportadas: ficar parado 10, chutar 20, desviar 20, avançar/recuar 30, mover = distância / 6 m/s convertida em ticks, no máximo 60). Quando a ação de algum jogador termina, a simulação PAUSA e volta ao PLANNING para quem ficou livre; a ação do outro jogador continua de onde estava. Quem está numa ação mais longa fica preso (sem poder trocar de ação) até ela terminar, e nesse intervalo o outro pode agir de novo. A câmera pode seguir a bola.

4) FÍSICA DA BOLA (script próprio, sem RigidBody3D)
- Estado: position, velocity, spin (Vector3).
- A cada tick: gravidade (0, -9.8, 0); arrasto linear proporcional à velocidade; força de Magnus = k_magnus * spin.cross(velocity); integração de Euler semi-implícita; quique no chão (se y < raio e vy < 0: vy = -vy * 0.6 e atrito horizontal 0.9); atrito de rolamento quando em contato com o chão.
- O chute define a velocity pela direção, força e elevação, e o spin pelos dois efeitos (lateral = eixo Y, vertical = eixo horizontal perpendicular à direção do chute). Constantes (k_drag, k_magnus etc.) como variáveis exportadas.
- Sem aleatoriedade em nenhum lugar: a mesma ação com os mesmos valores deve dar o mesmo resultado sempre.

5) GOL E PLACAR
- Se a bola cruzar a linha de fundo entre as traves, some 1 ao placar, recoloque bola e jogadores nas posições iniciais e volte ao PLANNING. Mostre o placar na tela.

6) VERIFICAÇÃO (obrigatória, no mesmo pedido)
- Rode o projeto com o MCP, leia a saída de debug, corrija todos os erros e repita até rodar sem erros.
- O espectro azul tem que coincidir exatamente com o que acontece na execução.
- Responda no fim com no máximo 5 linhas: o que foi feito, o que testou e o que falta.
```

Se depois do pedido sobrar cota, o próximo uso do agente é pedir ajustes pontuais com base no que você viu rodando.

## Riscos e decisões em aberto

O maior risco é de escopo: "um jogo completo" é grande, então cada fase termina com algo jogável antes de começar a próxima.

**Riscos:**

- **Cota do agente.** Meça no primeiro dia quanto uma requisição realmente consome. Se for pouco, o plano de trabalhar com chat e editor continua valendo; se der para folgar, o agente assume mais tarefas.
- **Vários jogadores por lado.** No 3 contra 3 online, cada pessoa controla um jogador e o jogo pausa sempre que alguém fica livre; falta definir como os outros esperam ou escolhem nesse momento. Isso muda o design e precisa ser testado cedo. O mesmo vale para mostrar todas as opções do adversário: com vários jogadores, a tela pode ficar poluída.
- **Determinismo no futuro.** Ponto flutuante pode dar resultados diferentes entre máquinas, o que importa porque o 3 contra 3 será online. Para o 1 contra 1 local não é problema.
- **Arte por IA.** Modelos gerados costumam precisar de limpeza e de esqueleto para animar, então deixe a arte para depois da jogabilidade.

**Decisões que preciso de você:**

- [x] Turnos simultâneos (como no Your Only Move Is HUSTLE) ou alternados?
- [x] Decidido: começa em 1 contra 1; no 3 contra 3 online, cada pessoa controla um jogador.
- [x] Decidido: 1 contra 1 no protótipo e no jogo local, 3 contra 3 só online (máximo 3 por lado), sem 2 contra 2.
- [x] Decidido: cada ação dura um número de ticks e o jogo pausa quando alguém fica livre.

* [x] Decidido: no 3 contra 3 online, o goleiro de cada time é controlado por IA.
* [x] Decidido: o jogo pausa quando alguém fica livre. Ações pesadas custam mais ticks e deixam o jogador preso até terminarem, e o outro age de novo nesse intervalo.
