/// Erro de transporte (BLE caiu, serviço ausente...). A mensagem vai para a tela.
class ElmLinkException implements Exception {
  ElmLinkException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Link bruto com o adaptador: só conectar, escrever bytes e receber bytes.
/// O protocolo ELM327 fica em [ElmSource], independente do transporte,
/// como `obd_elm.h` / `obd_ble.h` no firmware.
abstract class ElmLink {
  /// Descrição para a tela (ex.: "KONNWEI").
  String get name;
  bool get isConnected;

  /// Bytes recebidos do adaptador (notificações de FFF1).
  Stream<List<int>> get incoming;

  /// Conecta. Lança [ElmLinkException] com a causa se falhar.
  Future<void> connect();

  /// Envia bytes (fragmenta pelo MTU se preciso). Lança [ElmLinkException] se o link caiu.
  Future<void> write(List<int> bytes);

  /// Sinal em dBm, ou 0 se indisponível.
  Future<int> readRssi();

  Future<void> disconnect();
}
