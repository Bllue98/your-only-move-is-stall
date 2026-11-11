# NOTAS

## Decisões (opção mais simples quando havia ambiguidade)
- Sem colisão bola×jogador nem bola×gol (só caixas visuais); paredes invisíveis refletem a bola fora da boca do gol.
- Bola e jogadores usam `position` do Node3D como estado. Os espectros rodam a mesma simulação (`_run_log`) em cópias (`copy_from`) criadas em memória, com a mesma ordem de tick: jogadores → bola.
- Chute: ângulo 0 = reto para o gol da direita (+x); efeito vertical positivo = topspin. Chute só confere distância (≤1.5 m) ao confirmar: se longe, mostra "longe demais" e continua em PLANNING; se o tempo acabar, vira "ficar parado".
- Sem destino/ação escolhida ao confirmar = ficar parado (10 ticks). A aba ativa (Mover/Chutar) define a ação.
- Adversário: rodízio parado → avançar → recuar → desviar esq. → desviar dir.; recuar vai para o gol dele (+x); desvios andam em ±z. Espectro vermelho mostra as 5 (a próxima do rodízio é mais forte).
- Se o azul está preso numa ação longa, não há PLANNING: o adversário escolhe e a simulação segue. Se só o adversário está preso, o azul planeja (espectro vermelho = ação restante dele).
- Gol: +1 no placar, bola/jogadores/rodízio reiniciados, volta ao PLANNING.
- Câmera fixa (não segue a bola). Constantes de física são `@export` em ball.gd; durações em player.gd.
- Autoteste: `selftest` (export em game.gd, desligado) compara espectro azul × execução real (chute e mover), "longe demais" e gol.

## Falta
- Colisões/disputa de bola, arte, câmera seguindo a bola, linhas de área, IA mais esperta, adversário chutando.
