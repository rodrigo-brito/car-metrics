// Case frontal para tela TFT 2.8" (ESP32 CYD) — reconstrução paramétrica
// Engenharia reversa de "2.8inch Front Case big hole.3mf" (Onshape, v39).
// Referencial do original: z = 0 no degrau onde a placa apoia, frente em -z,
// a abertura (tampa traseira) em +z. Imprime com a frente no prato.
//
// Duas peças: `case` (o original) e `tampa` — a tampa traseira do case
// (plana, colada na borda do case) é também a moldura que apoia na borda do furo do painel (Pajero TR4) e leva
// a saia com garras que entra no furo. O case fica na FRENTE do painel: ele
// tem 54,1 mm de altura e o furo só 44, nem o vidro da tela passa por ele.

/* [Case] */
largura = 90;        // [60:150]  dimensão externa em x
altura = 54.1;       // [40:100]  dimensão externa em y
raio = 4;            // [1:10]    raio dos cantos externos
parede = 1.5;        // [1:3]
frente = 1.0;        // [0.6:3]   espessura da placa da frente
chanfro = 0.5;       // [0:1.5]   chanfro 45° na borda frontal da janela
fundo = 9.4;         // [4:30]    altura da cavidade acima do degrau da placa

/* [Tela] */
bolso_prof = 3.9;    // [2:8]     profundidade do bolso do vidro (abaixo do degrau)
bolso_larg = 71.6;   // [40:140]  largura do bolso do vidro (em y vai de parede a parede)
bolso_dx = -0.3;     // [-20:20]  deslocamento do bolso em x
janela_larg = 58.4;  // [20:140]  área visível
janela_alt = 44.3;   // [20:90]
janela_dx = 2.6;     // [-20:20]
janela_dy = 0;       // [-20:20]

/* [Conectores] */
usb = true;          // rasgo na parede esquerda (x negativo)
usb_larg = 29.6;     // [5:40]   de −14,8 a +14,8: JST + USB-C + micro-USB
usb_alt = 6;         // [3:12]
usb_raio = 1.5;      // [0:3]
usb_dy = 0;          // [-25:25]  centro do rasgo em y (original: −4,81, só o USB)
usb_dz = 0;          // [-4:10]   base do rasgo acima do degrau

/* [Tampa traseira] */
canal_prof = 1;      // [0:2]     canaleta em V nas paredes longas (encaixe da tampa)
canal_alt = 1.5;     // [0.5:3]
canal_desce = 1.25;  // [0.5:5]   centro da canaleta abaixo da borda
canal_comp = 80;     // [20:140]

/* [Ganchos (encaixe case ↔ tampa sem cola)] */
ganchos = true;      // ganchos nas paredes curtas do case que estalam em janelas da tampa
gancho_larg = 6;     // [4:12]
gancho_esp = 1.0;    // [0.8:1.5] espessura do braço (a parede é afinada por fora)
gancho_fenda = 0.8;  // [0.5:1.5] fendas que soltam o braço da parede
gancho_raiz = 5;     // [3:8]     comprimento do braço abaixo da borda
gancho_dy = 11;      // [0:20]    posição dos dois ganchos da parede direita (±y), fora da saia
dente = 0.8;         // [0.4:1.2] saliência do dente para dentro do case
dente_alt = 0.6;     // [0.3:1]   altura da face que trava
dente_rampa = 1.0;   // [0.5:2]   rampa de entrada
gancho_folga = 0.2;  // [0.1:0.4] folga do braço na janela e do dente sobre a placa

/* [Painel (TR4)] */
peca = "montado";    // ["case", "tampa", "montado", "explodido"]
// Contorno do furo (desenho medido): base reta, pontas arredondadas e topo
// em arco suave, mais alto no centro que nos "ombros".
furo_larg = 140;     // [60:240]  largura total (ponta a ponta)
furo_alt = 45;       // [30:140]  altura no centro (topo do arco)
furo_alt_lado = 42;  // [30:140]  altura nos ombros (onde o arco encontra as pontas)
furo_ombro = 97.4;   // [40:200]  distância entre os ombros
furo_reto = 100;     // [40:200]  comprimento da base reta
furo_ponta = 22;     // [5:60]    altura da ponta lateral acima da base
furo_dx = 2.6;       // [-40:40]  centro do furo no referencial do case (2,6 = janela centrada)
furo_dy = -24;       // [-60:20]  base do furo no referencial do case (−24 = case no meio da moldura)
aba_cima = 5;        // [0:20]    apoio disponível em volta do furo
aba_baixo = 2;       // [0:20]
aba_lado = 5;        // [0:20]
aba_esp = 2;         // [1.2:4]   espessura da tampa/moldura
folga = 0.3;         // [0:1]     folga da saia no furo
saia_alt = 9;        // [0:40]    saia que entra no furo (chapa + 0,2 + rampa + ~1)
saia_esp = 1.5;      // [1:3]
painel_esp = 4;      // [0:8]     espessura da peça do painel na borda do furo
garra_saida = 1.2;   // [0:3]     0 = sem garras
garra_rampa = 3;     // [1:6]
garra_larg = 12;     // [4:30]
garra_x = 25;        // [5:45]    garras em x = ±garra_x (do centro do furo), em cima e embaixo
cabo = true;         // passagem do cabo USB pela tampa, ao lado do case
cabo_larg = 8;       // [4:30]
cabo_alt = 6;        // [4:30]
cabo_dx = -57;       // [-80:80]  centro da passagem (lado do rasgo USB)
cabo_dy = 0;         // [-20:20]
labio = false;       // lábio + crista dentro da cavidade (alternativa aos ganchos)
tampa_folga = 0.2;   // [0:0.6]   folga do lábio da tampa dentro do case
labio_alt = 2.5;     // [1.5:5]
labio_esp = 1.2;     // [0.8:2]

$fn = 48;
eps = 0.005;
z_frente = -(frente + bolso_prof);
raio_int = max(0.01, raio - parede);
li = largura - 2 * parede;   // cavidade interna
ai = altura - 2 * parede;

module rrect(w, h, r) {
    r2 = min(r, w / 2 - eps, h / 2 - eps);
    offset(r = r2) offset(delta = -r2) square([w, h], center = true);
}

// extrusão no plano YZ ao longo de x (2D x→y, 2D y→z)
module ao_longo_x(comp, center = true) rotate([90, 0, 90]) linear_extrude(comp, center = center) children();

module corpo() {
    translate([0, 0, z_frente]) linear_extrude(fundo - z_frente) rrect(largura, altura, raio);
}

ca = canal_alt / 2 * (canal_prof + 0.1) / max(canal_prof, eps);

module cavidades() union() {
    // cavidade da placa, acima do degrau
    translate([0, 0, 0]) linear_extrude(fundo + 1) rrect(li, ai, raio_int);
    // bolso do vidro
    // (0,005 mm mais largo que a cavidade: evita face coplanar com a parede)
    translate([bolso_dx, 0, -bolso_prof]) linear_extrude(bolso_prof + 1) square([bolso_larg, ai + 2 * eps], center = true);
    // janela
    translate([janela_dx, janela_dy, z_frente - 1]) linear_extrude(frente + 2) square([janela_larg, janela_alt], center = true);
    if (chanfro > 0) translate([janela_dx, janela_dy, 0]) hull() {
        translate([0, 0, z_frente - 1]) linear_extrude(1 + eps) square([janela_larg + 2 * chanfro + 2, janela_alt + 2 * chanfro + 2], center = true);
        translate([0, 0, z_frente + chanfro]) linear_extrude(eps) square([janela_larg, janela_alt], center = true);
    }
    // rasgo do USB na parede esquerda
    if (usb) translate([-largura / 2 + parede / 2, usb_dy, usb_dz + usb_alt / 2])
        ao_longo_x(parede + 2) rrect(usb_larg, usb_alt, usb_raio);
    // canaleta em V da tampa traseira
    if (canal_prof > 0) for (s = [-1, 1]) translate([0, s * ai / 2, fundo - canal_desce]) mirror([0, s < 0 ? 1 : 0, 0])
        ao_longo_x(canal_comp) polygon([[-0.1, -ca], [canal_prof, 0], [-0.1, ca]]);  // V prolongada 0,1 para dentro, sem vértice no plano da parede
}

// ---- Ganchos ----
// Referencial local: origem na face externa da parede curta, +x para dentro
// do case, y ao longo da parede. `s` = −1 parede esquerda, +1 direita.
// Na parede com o rasgo do USB o gancho fica em cima do rasgo: a faixa de
// parede acima dele (presa nas duas pontas) é a mola, sem fendas. Na outra
// parede o braço é solto por duas fendas e afinado por fora.
function ganchos_pos() = [for (s = [-1, 1]) for (yc = (s < 0 && usb) ? [usb_dy] : [-gancho_dy, gancho_dy]) [s, yc]];
function gancho_viga(s) = s < 0 && usb;           // mola = faixa sobre o rasgo
module no_gancho(s, yc) translate([s * largura / 2, yc, 0]) mirror([s > 0 ? 1 : 0, 0, 0]) children();

// cortes no case: duas fendas e o rebaixo externo que afinam o braço
module ganchos_cortes() if (ganchos) for (p = ganchos_pos()) if (!gancho_viga(p[0])) no_gancho(p[0], p[1]) {
    for (t = [-1, 1]) translate([-1, t * (gancho_larg + gancho_fenda) / 2 - gancho_fenda / 2, fundo - gancho_raiz])
        cube([parede + 1.1, gancho_fenda, gancho_raiz + 1]);
    translate([-1, -gancho_larg / 2 - gancho_fenda, fundo - gancho_raiz])
        cube([1 + parede - gancho_esp, gancho_larg + 2 * gancho_fenda, gancho_raiz + 1]);
}

// o que sobe acima da borda: braço + dente (unido DEPOIS da cavidade)
module ganchos_corpo() if (ganchos) for (p = ganchos_pos()) no_gancho(p[0], p[1]) {
    x0 = gancho_viga(p[0]) ? 0 : parede - gancho_esp;   // face externa do braço
    zc = fundo + aba_esp + gancho_folga;                 // face que trava, logo acima da placa
    translate([x0, -gancho_larg / 2, fundo - 0.5])
        cube([parede - 0.02 - x0, gancho_larg, 0.5 + aba_esp + gancho_folga + dente_alt + dente_rampa + 0.1]);  // 0,1 acima do dente
    translate([parede - 0.3, 0, zc]) rotate([90, 0, 0]) linear_extrude(gancho_larg - 0.02, center = true)   // 0,02 mais estreito que o braço: sem face coincidente
        polygon([[0, 0], [0.3 + dente, 0], [0.3 + dente, dente_alt], [0, dente_alt + dente_rampa]]);
}

// janelas na tampa por onde o braço passa (o dente flexiona `dente − folga` para passar)
module ganchos_janelas() if (ganchos) for (p = ganchos_pos()) no_gancho(p[0], p[1])
    translate([-gancho_folga, -gancho_larg / 2 - gancho_folga, z_tampa - 1])
        cube([parede + 2 * gancho_folga, gancho_larg + 2 * gancho_folga, aba_esp + 2]);

// ---- Tampa / moldura ----
z_tampa = fundo;                 // a placa da tampa começa na borda do case
z_painel = z_tampa + aba_esp;    // face que apoia no painel
tf = tampa_folga;
cv = canal_alt / 2 - 0.1;        // crista da tampa, 0,1 menor que a canaleta

// contorno do furo, base em y = 0, centrado em x
function bez2(p0, p1, p2, n = 16) = [for (i = [0 : n]) let(t = i / n) (1 - t) * (1 - t) * p0 + 2 * (1 - t) * t * p1 + t * t * p2];
function furo_topo(x) = furo_alt - (furo_alt - furo_alt_lado) * pow(x / (furo_ombro / 2), 2);
function furo_pts() = let(
    hr = furo_reto / 2, hw = furo_larg / 2, ho = furo_ombro / 2,
    baixo = bez2([hr, 0], [hw - 1.5, furo_ponta * 0.2], [hw, furo_ponta]),            // ponta, metade de baixo
    cima = bez2([hw, furo_ponta], [hw - 4, furo_alt_lado - 1.5], [ho, furo_alt_lado]), // ponta, metade de cima
    topo = [for (i = [1 : 31]) let(x = ho - 2 * ho * i / 32) [x, furo_topo(x)]],
    dir = concat(baixo, cima),
    esq = [for (i = [len(dir) - 1 : -1 : 0]) [-dir[i][0], dir[i][1]]]
) concat(dir, topo, esq);
module furo2d() translate([furo_dx, furo_dy]) polygon(furo_pts());

module tampa() difference() {
    union() {
        // placa: moldura em volta do furo ∪ contorno do case (fecha a cavidade)
        translate([0, 0, z_tampa]) linear_extrude(aba_esp) union() {
            // furo crescido pela aba (5 em cima e dos lados), cortado a 2 mm abaixo da base reta
            intersection() {
                offset(r = max(aba_cima, aba_lado)) furo2d();
                translate([-500, furo_dy - aba_baixo]) square(1000);
            }
            rrect(largura, altura, raio);
        }
        // lábio que entra na cavidade do case (só com labio = true)
        if (labio) translate([0, 0, z_tampa - labio_alt]) linear_extrude(labio_alt + eps) difference() {
            rrect(li - 2 * tf, ai - 2 * tf, raio_int - tf);
            rrect(li - 2 * tf - 2 * labio_esp, ai - 2 * tf - 2 * labio_esp, max(0.01, raio_int - tf - labio_esp));
        }
        // crista em V que estala na canaleta das paredes longas
        if (labio && canal_prof > 0) for (s = [-1, 1]) translate([0, s * (ai / 2 - tf), fundo - canal_desce]) mirror([0, s < 0 ? 1 : 0, 0])
            ao_longo_x(canal_comp - 1) polygon([[-labio_esp + 0.1, -cv], [canal_prof + tf - 0.1, 0], [-labio_esp + 0.1, cv]]);  // nasce dentro do lábio, não na face interna
        // saia que entra no furo do painel
        if (saia_alt > 0) translate([furo_dx, furo_dy, z_painel - eps]) linear_extrude(saia_alt + eps) difference() {
            offset(delta = -folga) translate([-furo_dx, -furo_dy]) furo2d();
            offset(delta = -folga - saia_esp) translate([-furo_dx, -furo_dy]) furo2d();
        }
        // garras: duas na base reta, duas no arco de cima (giradas com a tangente)
        if (saia_alt > 0 && garra_saida > 0) {
            zg = z_painel + painel_esp + 0.2;        // ombro 0,2 além da peça do painel
            for (t = [-1, 1]) {
                x = t * garra_x;
                inc = atan(-2 * (furo_alt - furo_alt_lado) * x / pow(furo_ombro / 2, 2));
                garra_em([furo_dx + x, furo_dy + folga, zg], 180, garra_larg);
                garra_em([furo_dx + x, furo_dy + furo_topo(x) - folga, zg], inc, garra_larg);
            }
        }
    }
    if (cabo) translate([cabo_dx, cabo_dy, z_tampa - 1]) linear_extrude(aba_esp + 2) rrect(cabo_larg, cabo_alt, 3);
    ganchos_janelas();
}

// garra com a face colada na saia em `pos`, apontando para fora no ângulo `ang`
// (0 = +y, 180 = -y). Ombro plano virado para a placa, rampa para a ponta.
module garra_em(pos, ang, w) translate(pos) rotate([0, 0, ang]) ao_longo_x(w)
    polygon([[-0.3, 0], [garra_saida, 0], [-0.3, garra_rampa]]);

module case() union() { difference() { corpo(); cavidades(); ganchos_cortes(); } ganchos_corpo(); }

if (peca == "case") case();
else if (peca == "tampa") translate([0, 0, -z_tampa]) tampa();   // face plana (lado do case) no prato, saia para cima
else if (peca == "montado") { case(); tampa(); }
else { case(); translate([0, 0, 15]) tampa(); }
