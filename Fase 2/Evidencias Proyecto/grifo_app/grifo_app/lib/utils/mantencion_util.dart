import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'vida_util.dart' show fechaVisible;

/// Cuántos días antes del vencimiento / de la mantención se empieza a avisar.
const diasAvisoDocumento = 30;
const diasAvisoMantencion = 30;

enum NivelAlerta { ok, proximo, vencido, sinDato }

/// Documento de un carro con fecha de vencimiento (columna en la tabla carro).
class DocumentoCarro {
  final String campo;
  final String nombre;
  final String corto;
  const DocumentoCarro(this.campo, this.nombre, this.corto);
}

const documentosCarro = [
  DocumentoCarro('revision_tecnica_vence', 'Revisión técnica', 'Revisión técnica'),
  DocumentoCarro('permiso_circulacion_vence', 'Permiso de circulación', 'Permiso circulación'),
  DocumentoCarro('soap_vence', 'SOAP (seguro obligatorio)', 'SOAP'),
];

class AlertaCarro {
  final String titulo;
  final String detalle;
  final NivelAlerta nivel;
  const AlertaCarro(this.titulo, this.detalle, this.nivel);

  bool get activa => nivel == NivelAlerta.vencido || nivel == NivelAlerta.proximo;

  Color get color {
    switch (nivel) {
      case NivelAlerta.vencido:
        return AppColors.rojoAlerta;
      case NivelAlerta.proximo:
        return Colors.orange.shade700;
      case NivelAlerta.ok:
        return AppColors.verde;
      case NivelAlerta.sinDato:
        return AppColors.textoSecundario;
    }
  }
}

DateTime? _fecha(dynamic v) => v == null ? null : DateTime.tryParse(v.toString());
int? _entero(dynamic v) => v == null ? null : int.tryParse(v.toString());

DateTime _hoy() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

String _dias(int n) => '$n día${n == 1 ? '' : 's'}';

String _miles(int n) {
  final s = n.abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return n < 0 ? '-$b' : b.toString();
}

String km(int n) => '${_miles(n)} km';

/// Estado de un documento con vencimiento (revisión técnica, permiso, SOAP).
AlertaCarro evaluarDocumento(String titulo, dynamic fechaRaw) {
  final f = _fecha(fechaRaw);
  if (f == null) return AlertaCarro(titulo, 'Sin fecha registrada', NivelAlerta.sinDato);
  final dias = DateTime(f.year, f.month, f.day).difference(_hoy()).inDays;
  if (dias < 0) return AlertaCarro(titulo, 'Venció el ${fechaVisible(f)} (hace ${_dias(-dias)})', NivelAlerta.vencido);
  if (dias == 0) return AlertaCarro(titulo, 'Vence hoy (${fechaVisible(f)})', NivelAlerta.proximo);
  if (dias <= diasAvisoDocumento) return AlertaCarro(titulo, 'Vence en ${_dias(dias)} (${fechaVisible(f)})', NivelAlerta.proximo);
  return AlertaCarro(titulo, 'Vigente hasta el ${fechaVisible(f)}', NivelAlerta.ok);
}

/// Estado de la mantención: por tiempo (cada N meses) y por kilometraje.
List<AlertaCarro> evaluarMantencion(Map<String, dynamic> carro) {
  final ultima = _fecha(carro['mantencion_ultima_fecha']);
  final ultimoKm = _entero(carro['mantencion_ultimo_km']);
  final kmActual = _entero(carro['km_actual']);
  final cadaMeses = _entero(carro['mantencion_cada_meses']) ?? 12;
  final cadaKm = _entero(carro['mantencion_cada_km']) ?? 10000;

  if (ultima == null && ultimoKm == null) {
    return const [AlertaCarro('Mantención', 'Sin mantención registrada', NivelAlerta.sinDato)];
  }

  final alertas = <AlertaCarro>[];

  if (ultima != null && cadaMeses > 0) {
    final proxima = DateTime(ultima.year, ultima.month + cadaMeses, ultima.day);
    final dias = proxima.difference(_hoy()).inDays;
    if (dias < 0) {
      alertas.add(AlertaCarro('Mantención (fecha)', 'Ya pasaron los $cadaMeses meses: tocaba el ${fechaVisible(proxima)} (hace ${_dias(-dias)})', NivelAlerta.vencido));
    } else if (dias <= diasAvisoMantencion) {
      alertas.add(AlertaCarro('Mantención (fecha)', 'Debe ir a taller en ${_dias(dias)} (${fechaVisible(proxima)})', NivelAlerta.proximo));
    } else {
      alertas.add(AlertaCarro('Mantención (fecha)', 'Próxima por fecha: ${fechaVisible(proxima)}', NivelAlerta.ok));
    }
  }

  if (ultimoKm != null && cadaKm > 0) {
    if (kmActual == null) {
      alertas.add(const AlertaCarro('Mantención (km)', 'Falta registrar el kilometraje actual', NivelAlerta.sinDato));
    } else {
      final restante = ultimoKm + cadaKm - kmActual;
      if (restante <= 0) {
        alertas.add(AlertaCarro('Mantención (km)', 'Superó el intervalo de ${km(cadaKm)} por ${km(-restante)}', NivelAlerta.vencido));
      } else if (restante <= cadaKm * 0.1) {
        alertas.add(AlertaCarro('Mantención (km)', 'Faltan ${km(restante)} para la próxima mantención', NivelAlerta.proximo));
      } else {
        alertas.add(AlertaCarro('Mantención (km)', 'Faltan ${km(restante)} para la próxima mantención', NivelAlerta.ok));
      }
    }
  }

  return alertas;
}

/// Todas las comprobaciones de un carro (documentos + mantención).
List<AlertaCarro> evaluarCarro(Map<String, dynamic> carro) => [
      for (final d in documentosCarro) evaluarDocumento(d.nombre, carro[d.campo]),
      ...evaluarMantencion(carro),
    ];

/// Solo las que requieren atención (vencidas o por vencer).
List<AlertaCarro> alertasActivas(Map<String, dynamic> carro) {
  final lista = <AlertaCarro>[
    for (final d in documentosCarro) evaluarDocumento(d.corto, carro[d.campo]),
    ...evaluarMantencion(carro),
  ];
  return lista.where((a) => a.activa).toList();
}

bool tieneVencidas(List<AlertaCarro> alertas) => alertas.any((a) => a.nivel == NivelAlerta.vencido);

Widget chipAlerta(AlertaCarro a) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: a.color, borderRadius: BorderRadius.circular(10)),
      child: Text(
        '${a.titulo} · ${a.nivel == NivelAlerta.vencido ? 'vencido' : 'por vencer'}',
        style: const TextStyle(color: Colors.white, fontSize: 11),
      ),
    );
