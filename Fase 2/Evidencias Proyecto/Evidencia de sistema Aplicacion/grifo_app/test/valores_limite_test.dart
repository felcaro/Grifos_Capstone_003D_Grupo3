import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grifo_app/utils/mantencion_util.dart';
import 'package:grifo_app/utils/vida_util.dart';
import 'package:grifo_app/theme/app_colors.dart';

void main() {
  group('Sección 5.2 - Casos de Valores Límite (VL-01 a VL-18)', () {
    // =========================================================================
    // 1. Mantención por Kilometraje (VL-01 a VL-09)
    // Base: Última mantención a 5.000 km, periodicidad cada 10.000 km.
    // Próxima mantención requerida a los 15.000 km.ñ
    // Umbral de alerta naranja (10% de 10.000 km): 1.000 km restantes.
    // =========================================================================
    const baseCarroKm = {
      'mantencion_ultimo_km': 5000,
      'mantencion_cada_km': 10000,
    };

    test('VL-01: Mantención km - Quedan 1001 km (Fuera de umbral de alerta) -> OK (Verde)', () {
      final carro = Map<String, dynamic>.from(baseCarroKm)..['km_actual'] = 13999;
      final alertas = evaluarMantencion(carro);
      final alertaKm = alertas.firstWhere((a) => a.titulo == 'Mantención (km)');

      expect(alertaKm.nivel, equals(NivelAlerta.ok));
      expect(alertaKm.detalle, contains('1.001 km'));
    });

    test('VL-02: Mantención km - Quedan exactamente 1000 km (Límite superior del 10%) -> Próximo (Naranja)', () {
      final carro = Map<String, dynamic>.from(baseCarroKm)..['km_actual'] = 14000;
      final alertas = evaluarMantencion(carro);
      final alertaKm = alertas.firstWhere((a) => a.titulo == 'Mantención (km)');

      expect(alertaKm.nivel, equals(NivelAlerta.proximo));
      expect(alertaKm.detalle, contains('1.000 km'));
    });

    test('VL-03: Mantención km - Quedan 999 km (Dentro del umbral de alerta) -> Próximo (Naranja)', () {
      final carro = Map<String, dynamic>.from(baseCarroKm)..['km_actual'] = 14001;
      final alertas = evaluarMantencion(carro);
      final alertaKm = alertas.firstWhere((a) => a.titulo == 'Mantención (km)');

      expect(alertaKm.nivel, equals(NivelAlerta.proximo));
      expect(alertaKm.detalle, contains('999 km'));
    });

    test('VL-04: Mantención km - Queda 1 km para el intervalo -> Próximo (Naranja)', () {
      final carro = Map<String, dynamic>.from(baseCarroKm)..['km_actual'] = 14999;
      final alertas = evaluarMantencion(carro);
      final alertaKm = alertas.firstWhere((a) => a.titulo == 'Mantención (km)');

      expect(alertaKm.nivel, equals(NivelAlerta.proximo));
      expect(alertaKm.detalle, contains('1 km'));
    });

    test('VL-05: Mantención km - Intervalo alcanzado (0 km restantes) -> Vencido (Rojo)', () {
      final carro = Map<String, dynamic>.from(baseCarroKm)..['km_actual'] = 15000;
      final alertas = evaluarMantencion(carro);
      final alertaKm = alertas.firstWhere((a) => a.titulo == 'Mantención (km)');

      expect(alertaKm.nivel, equals(NivelAlerta.vencido));
      expect(alertaKm.detalle, contains('Superó el intervalo de 10.000 km por 0 km'));
    });

    test('VL-06: Mantención km - Intervalo superado por 1 km -> Vencido (Rojo)', () {
      final carro = Map<String, dynamic>.from(baseCarroKm)..['km_actual'] = 15001;
      final alertas = evaluarMantencion(carro);
      final alertaKm = alertas.firstWhere((a) => a.titulo == 'Mantención (km)');

      expect(alertaKm.nivel, equals(NivelAlerta.vencido));
      expect(alertaKm.detalle, contains('Superó el intervalo de 10.000 km por 1 km'));
    });

    test('VL-07: Mantención km - Intervalo superado ampliamente (500 km) -> Vencido (Rojo)', () {
      final carro = Map<String, dynamic>.from(baseCarroKm)..['km_actual'] = 15500;
      final alertas = evaluarMantencion(carro);
      final alertaKm = alertas.firstWhere((a) => a.titulo == 'Mantención (km)');

      expect(alertaKm.nivel, equals(NivelAlerta.vencido));
      expect(alertaKm.detalle, contains('Superó el intervalo de 10.000 km por 500 km'));
    });

    test('VL-08: Mantención km - Falta kilometraje actual -> Sin dato (Gris)', () {
      final carro = Map<String, dynamic>.from(baseCarroKm)..['km_actual'] = null;
      final alertas = evaluarMantencion(carro);
      final alertaKm = alertas.firstWhere((a) => a.titulo == 'Mantención (km)');

      expect(alertaKm.nivel, equals(NivelAlerta.sinDato));
      expect(alertaKm.detalle, equals('Falta registrar el kilometraje actual'));
    });

    test('VL-09: Mantención km - Sin registro previo -> Sin mantención registrada', () {
      final carro = <String, dynamic>{
        'mantencion_ultimo_km': null,
        'mantencion_ultima_fecha': null,
        'km_actual': 10000,
      };
      final alertas = evaluarMantencion(carro);

      expect(alertas.length, equals(1));
      expect(alertas.first.nivel, equals(NivelAlerta.sinDato));
      expect(alertas.first.detalle, equals('Sin mantención registrada'));
    });

    // =========================================================================
    // 2. Mantención por Fecha (VL-10 a VL-13)
    // Periodicidad: 12 meses. Días de aviso preventivo: 30 días.
    // =========================================================================
    test('VL-10: Mantención fecha - Sin fecha de última mantención', () {
      final carro = <String, dynamic>{
        'mantencion_ultima_fecha': null,
        'mantencion_ultimo_km': null,
      };
      final alertas = evaluarMantencion(carro);
      expect(alertas.first.nivel, equals(NivelAlerta.sinDato));
      expect(alertas.first.detalle, equals('Sin mantención registrada'));
    });

    test('VL-11: Mantención fecha - Próxima en 31 días (Fuera de aviso) -> OK (Verde)', () {
      final hoy = DateTime.now();
      // Si la próxima es en 31 días y cadaMeses es 12, la última fue hace (365 - 31) días
      final fechaProxima = DateTime(hoy.year, hoy.month, hoy.day).add(const Duration(days: 31));
      final fechaUltima = DateTime(fechaProxima.year - 1, fechaProxima.month, fechaProxima.day);

      final carro = <String, dynamic>{
        'mantencion_ultima_fecha': fechaUltima.toIso8601String(),
        'mantencion_cada_meses': 12,
      };
      final alertas = evaluarMantencion(carro);
      final alertaFecha = alertas.firstWhere((a) => a.titulo == 'Mantención (fecha)');

      expect(alertaFecha.nivel, equals(NivelAlerta.ok));
      expect(alertaFecha.detalle, contains('Próxima por fecha'));
    });

    test('VL-12: Mantención fecha - Próxima en 30 días (Límite de aviso) -> Próximo (Naranja)', () {
      final hoy = DateTime.now();
      final fechaProxima = DateTime(hoy.year, hoy.month, hoy.day).add(const Duration(days: 30));
      final fechaUltima = DateTime(fechaProxima.year - 1, fechaProxima.month, fechaProxima.day);

      final carro = <String, dynamic>{
        'mantencion_ultima_fecha': fechaUltima.toIso8601String(),
        'mantencion_cada_meses': 12,
      };
      final alertas = evaluarMantencion(carro);
      final alertaFecha = alertas.firstWhere((a) => a.titulo == 'Mantención (fecha)');

      expect(alertaFecha.nivel, equals(NivelAlerta.proximo));
      expect(alertaFecha.detalle, contains('Debe ir a taller en 30 días'));
    });

    test('VL-13: Mantención fecha - Vencida ayer -> Vencido (Rojo)', () {
      final hoy = DateTime.now();
      final fechaProxima = DateTime(hoy.year, hoy.month, hoy.day).subtract(const Duration(days: 1));
      final fechaUltima = DateTime(fechaProxima.year - 1, fechaProxima.month, fechaProxima.day);

      final carro = <String, dynamic>{
        'mantencion_ultima_fecha': fechaUltima.toIso8601String(),
        'mantencion_cada_meses': 12,
      };
      final alertas = evaluarMantencion(carro);
      final alertaFecha = alertas.firstWhere((a) => a.titulo == 'Mantención (fecha)');

      expect(alertaFecha.nivel, equals(NivelAlerta.vencido));
      expect(alertaFecha.detalle, contains('Ya pasaron los 12 meses'));
    });

    // =========================================================================
    // 3. Vida Útil del Equipo Personal (VL-14 a VL-18)
    // Vida útil: 10 años.
    // Verde: > 730 días (2 años)
    // Naranja: 366 a 730 días (entre 1 y 2 años)
    // Rojo: <= 365 días (1 año o menos)
    // =========================================================================
    test('VL-14: Vida útil - Quedan más de 730 días (> 2 años) -> Verde', () {
      final hoy = DateTime.now();
      // Comprado hace 7 años (le quedan 3 años aprox ~ 1095 días)
      final fechaCompra = DateTime(hoy.year - 7, hoy.month, hoy.day);
      final res = calcularVidaUtil(fechaCompra.toIso8601String(), 10);

      expect(res, isNotNull);
      expect(res!.color, equals(AppColors.verde));
      expect(res.vencido, isFalse);
      expect(res.porVencer, isFalse);
      expect(res.diasRestantes, greaterThan(730));
    });

    test('VL-15: Vida útil - Quedan entre 366 y 730 días (1 a 2 años) -> Naranja', () {
      final hoy = DateTime.now();
      // Comprado hace 8 años y 6 meses (le queda 1.5 años ~ 547 días)
      final fechaCompra = DateTime(hoy.year - 8, hoy.month - 6, hoy.day);
      final res = calcularVidaUtil(fechaCompra.toIso8601String(), 10);

      expect(res, isNotNull);
      expect(res!.color, equals(Colors.orange.shade700));
      expect(res.vencido, isFalse);
      expect(res.porVencer, isFalse);
      expect(res.diasRestantes, inInclusiveRange(366, 730));
    });

    test('VL-16: Vida útil - Quedan 365 días o menos -> Rojo (Por vencer)', () {
      final hoy = DateTime.now();
      // Comprado hace 9 años y 6 meses (le quedan ~ 6 meses)
      final fechaCompra = DateTime(hoy.year - 9, hoy.month - 6, hoy.day);
      final res = calcularVidaUtil(fechaCompra.toIso8601String(), 10);

      expect(res, isNotNull);
      expect(res!.color, equals(AppColors.rojoAlerta));
      expect(res.vencido, isFalse);
      expect(res.porVencer, isTrue);
      expect(res.diasRestantes, lessThanOrEqualTo(365));
    });

    test('VL-17: Vida útil - Fecha de vencimiento alcanzada o superada -> Rojo (Vencido)', () {
      final hoy = DateTime.now();
      // Comprado hace 10 años y 1 mes (ya venció)
      final fechaCompra = DateTime(hoy.year - 10, hoy.month - 1, hoy.day);
      final res = calcularVidaUtil(fechaCompra.toIso8601String(), 10);

      expect(res, isNotNull);
      expect(res!.color, equals(AppColors.rojoAlerta));
      expect(res.vencido, isTrue);
      expect(res.diasRestantes, lessThan(0));
      expect(res.texto, contains('Vida útil vencida hace'));
    });

    test('VL-18: Vida útil - Sin fecha de compra -> Retorna null', () {
      final res = calcularVidaUtil(null, 10);
      expect(res, isNull);
    });
  });
}

