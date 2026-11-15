import 'package:flutter_test/flutter_test.dart';
import 'package:painel_tr4/data/vehicle_data.dart';

void main() {
  test('consumo por MAF: L/h = MAF × 3600 / (AFR × densidade)', () {
    final d = VehicleData()
      ..mafGs = 10
      ..speedKmh = 60;
    final t = TripData();
    deriveAndIntegrate(d, t, 0);
    expect(d.fuelLph, closeTo(10 * 3600 / (13.2 * 750), 1e-6));
    expect(d.kmPerL, closeTo(60 / (10 * 3600 / (13.2 * 750)), 1e-6));
  });

  test('sem MAF estima por speed-density com MAP, rpm e IAT (2.0 L, VE 0.85)', () {
    final d = VehicleData()
      ..mapKpa = 100
      ..rpm = 3000
      ..intakeC = 30
      ..speedKmh = 0;
    final t = TripData();
    deriveAndIntegrate(d, t, 0);
    final airDensity = 100 * 1000.0 / (287.0 * (30 + 273.15));
    final maf = 3000 / 60.0 / 2.0 * (2.0 / 1000.0) * airDensity * 0.85 * 1000.0;
    expect(maf, closeTo(48.85, 0.05));
    expect(d.fuelLph, closeTo(maf * 3600 / (13.2 * 750), 1e-6));
    expect(d.kmPerL, isNull, reason: 'parado não tem km/l');
  });

  test('sem MAF e sem MAP não há consumo', () {
    final d = VehicleData()..rpm = 2000;
    deriveAndIntegrate(d, TripData(), 100);
    expect(d.fuelLph, isNull);
    expect(d.kmPerL, isNull);
  });

  test('integra distância, combustível, máxima e tempo em movimento', () {
    final d = VehicleData()
      ..mafGs = 5
      ..speedKmh = 90;
    final t = TripData();
    for (var i = 0; i < 40; i++) {
      deriveAndIntegrate(d, t, 90000); // 40 × 90 s = 1 h
    }
    expect(t.distanceKm, closeTo(90, 1e-6));
    expect(t.fuelL, closeTo(5 * 3600 / (13.2 * 750), 1e-6));
    expect(t.maxSpeed, 90);
    expect(t.movingMs, 3600000);
    expect(t.avgKmPerL, closeTo(90 / t.fuelL, 1e-6));
    expect(t.avgSpeed, closeTo(90, 1e-6));
  });

  test('parado não conta tempo em movimento e a média fica indefinida sem combustível', () {
    final d = VehicleData()..speedKmh = 0;
    final t = TripData();
    deriveAndIntegrate(d, t, 5000);
    expect(t.movingMs, 0);
    expect(t.avgKmPerL, isNull);
    expect(t.avgSpeed, isNull);
  });

  test('nomes em português', () {
    expect(obdStateName(ObdState.waitingEcu), 'sem ECU (ignição?)');
    expect(fuelSystemName(2), 'malha fechada');
    expect(fuelSystemName(99), '--');
    expect(obdStdName(1), 'OBD-II (CARB)');
  });
}
