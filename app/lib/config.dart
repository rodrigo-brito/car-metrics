/// Parâmetros do veículo e do laço de leitura, espelhando o `config.h` do firmware.
library;

/// Trechos de nome que costumam indicar um adaptador OBD (ELM327 por BLE). Só servem para
/// destacar e ordenar a lista; qualquer dispositivo pode ser escolhido, e o último conectado vira o padrão.
const obdNameHints = ['KONNWEI', 'OBD', 'ELM', 'VLINK', 'V-LINK', 'VEEPEAK'];

/// Combustível: relação ar/combustível estequiométrica e densidade (g/L).
/// Gasolina pura 14.7 / 745 · Gasolina C (BR, ~27% etanol) 13.2 / 750 · Etanol 9.0 / 790
const fuelAfr = 13.2;
const fuelDensity = 750.0;

/// Motor, para estimar o fluxo de ar quando a ECU não expõe MAF (speed-density):
/// MAF ≈ rpm/60 × cilindrada/2 × densidade do ar(MAP, IAT) × eficiência volumétrica.
/// Carro: Mitsubishi Pajero TR4 2010, 2.0 16V flex (4G94 MIVEC).
const engineDisplacementL = 2.0;
const engineVe = 0.85;

/// Intervalos (ms)
const uiRefreshMs = 100; // redesenho da tela
const obdFastMs = 150; // ciclo mínimo da rodada rpm, velocidade, MAF/MAP (um PID por passo)
const obdSlowMs = 1000; // demais PIDs, em rodízio de 13 posições

/// Alertas em tela cheia (ms de exibição e limites)
const alertShowMs = 4000;
const alertCoolantC = 105.0;
const alertBatteryV = 12.0; // com motor ligado

/// Inclinômetro (graus). Faixas conservadoras para um SUV em trilha: o tombamento estático
/// de um utilitário fica perto de 35-40° de lateral, mas carga no teto, pneu murcho, degrau
/// ou buraco sob a roda baixa reduzem bastante essa margem.
const inclineRollWarn = 15.0;
const inclineRollDanger = 25.0;
const inclinePitchWarn = 20.0;
const inclinePitchDanger = 30.0;
