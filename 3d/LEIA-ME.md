# Case da tela 2.8" (ESP32 CYD) no painel da Pajero TR4

`case_tela_28.scad` tem duas peças (parâmetro `peca` no Customizer):

- **`case`** — o case original do 3MF, reconstruído (IoU 0,992, desvio médio
  0,007 mm). Imprime com a frente no prato.
- **`tampa`** — a tampa traseira do case, que é também a **moldura** que apoia
  na borda do furo e leva a **saia oval com garras** que entra no furo, mais
  as três janelas dos ganchos do case.
  Imprime com a face plana (lado do case) no prato e a saia para cima (o STL
  já sai assim).
- `montado` / `explodido` — só para olhar.

## Contorno do furo

Medido no painel: base reta de 100 mm, pontas arredondadas, topo em arco
suave com 45 mm de altura no centro e 42 mm nos ombros (97,4 mm entre eles),
140 mm de ponta a ponta (`furo_*`). A saia segue esse contorno com 0,3 mm de
folga. O case não passa pelo furo (54,1 > 45), por isso fica na frente do
painel e só a saia entra.

## Apoio em volta do furo e garras

A moldura é o contorno crescido 5 mm em cima e dos lados e cortada 2 mm
abaixo da base reta. A base do furo fica em y = −24 do case
(`furo_dy`), o que põe o case no meio da moldura: ele passa 1,05 mm além do
apoio embaixo e no centro do topo, e até 3,6 mm nos cantos de cima, onde o
arco desce. Confira no carro se isso encosta em algo.

Quatro garras de 12 mm: duas na base reta e duas no arco de cima, giradas com
a inclinação dele, em x = ±25 do centro do furo. O ombro de cada garra fica a
4,2 mm da moldura (peça do painel de 4 mm + 0,2) e a saia tem 9 mm.

## Cabo USB

O rasgo dos conectores fica na parede esquerda do case, do lado de fora do
painel. A tampa tem uma passagem de 8 × 6 ao lado do case (`cabo_dx = −57`),
dentro da área do furo, para o cabo voltar para dentro do painel. Entre a parede do
case e a ponta do furo há 25 mm: um plugue USB-C reto tem ~25 mm, então **use
cabo USB-C de 90°** ou aumente `cabo_larg` e desloque `cabo_dx`.

## Parâmetros que ainda dependem do carro

- `folga` (0,3) — saia 0,6 menor que o furo; se entrar frouxa, 0,15.
- `saia_alt` (9) — precisa de chapa + 0,2 + rampa (3) + ~1.
- `garra_saida` (1,2) — se a saia não flexionar o bastante, 0,8.

## Tampa ↔ case: ganchos (sem cola)

Três ganchos sobem da borda das paredes curtas do case e atravessam janelas
na tampa; um dente de 0,8 mm virado para dentro trava do lado do painel
(dentro do furo, sem tocar a chapa). Para soltar, empurre os três dentes para
fora com uma chave de fenda fina e puxe o case.

- Parede direita: dois braços em y = ±11, soltos por fendas de 0,8 e afinados
  para 1,0 mm por fora (`gancho_*`).
- Parede esquerda (a do rasgo dos conectores): um gancho só, no centro, sem
  fendas. A mola é a faixa de parede de 3,4 mm acima do rasgo, presa nas duas
  pontas.
- Folga de 0,2 na janela e 0,2 do dente sobre a placa. Se o encaixe ficar
  frouxo, `gancho_folga = 0.1`; se não entrar, `dente = 0.6`.
- `ganchos = false` volta à tampa lisa para colar; `labio = true` é a outra
  alternativa (lábio dentro da cavidade).

## Rasgo dos conectores e cabo

O rasgo da parede esquerda agora vai de −14,8 a +14,8 (29,6 × 6, R1,5) e
expõe o JST, o USB-C e o micro-USB; o original cobria só os dois USB. A
passagem do cabo na tampa é de 8 × 6 (`cabo_larg`/`cabo_alt`), ao lado do
case, dentro da área do furo.

## Render

    openscad -D 'peca="case"'  -o case.stl  case_tela_28.scad
    openscad -D 'peca="tampa"' -o tampa.stl case_tela_28.scad
