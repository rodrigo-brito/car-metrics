import '../data/vehicle_data.dart';

/// Interface comum das fontes de dados (simulação e ELM327), como o `ObdSource` do firmware.
abstract class ObdSource {
  /// Chamado quando o estado muda (conectando → inicializando → conectado...), para a tela acompanhar.
  void Function()? onStateChanged;

  /// Inicia a conexão. Pode levar alguns segundos. Devolve false se falhou (ver [lastError]).
  Future<bool> begin();

  /// Um passo de leitura: no ELM327, um único comando por chamada, nunca concorrentes.
  Future<void> update(VehicleData d);

  ObdState get state;
  String get name;
  String get lastError => '';
  String get protocol => '';

  /// Lê o modo 03 e preenche [VehicleData.dtcs].
  Future<void> requestDtcs(VehicleData d) async {}

  /// Modo 04. Devolve true se a ECU confirmou.
  Future<bool> clearDtcs(VehicleData d) async => false;

  int get signalDbm => 0;

  /// Encerra a conexão e libera recursos.
  Future<void> dispose() async {}
}
