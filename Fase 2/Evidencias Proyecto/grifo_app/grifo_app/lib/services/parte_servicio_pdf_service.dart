import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/parte_servicio.dart';

/// Genera el PDF del Parte de Servicio, imitando el formato del libro
/// físico (cabeceras celestes, tablas con borde, croquis, asistencia).
/// Solo usa caracteres Latin-1 (la fuente por defecto del PDF no soporta más).
class ParteServicioPdfService {
  static const _celeste = PdfColor.fromInt(0xFFB9D7EA);
  static const _borde = PdfColors.black;

  static final _bordeFino = pw.Border.all(color: _borde, width: 0.6);

  static Future<Uint8List> generar(ParteServicioData d) async {
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => [
          // ---- Título ----
          pw.Center(
            child: pw.Text(
              'PARTE DE SERVICIO\n${d.companiaNombre.toUpperCase()}',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 10),

          // ---- Datos del servicio ----
          _fila([_etiqueta('FECHA', flex: 1), _valor(d.fecha, flex: 3)], alinearDerecha: true),
          _fila([
            _etiqueta('UNIDAD'), _valor(d.unidad),
            _etiqueta('NOMBRE'), _valor(d.nombre),
          ]),
          _fila([
            _etiqueta('SERVICIO'), _valor(d.servicio),
            _etiqueta('RUT'), _valor(d.rut),
          ]),
          _fila([
            _etiqueta('DIRECCION'), _valor(d.direccion),
            _etiqueta('NRO OBAC'), _valor(d.nroObac),
          ]),
          _fila([
            _etiqueta('ODOMETRO'), _valor(d.odometroInicial),
            _etiqueta('FINAL'), _valor(d.odometroFinal),
          ]),
          _fila([
            _etiqueta('HORA SALIDA'), _valor(d.horaSalida),
            _etiqueta('HORA LLEGADA'), _valor(d.horaLlegada),
          ]),
          _fila([_etiqueta('6-0'), _valor(d.clave60, flex: 5)]),
          pw.SizedBox(height: 6),

          // ---- En el lugar ----
          _cabecera('EN EL LUGAR'),
          pw.Table(
            border: pw.TableBorder.all(color: _borde, width: 0.6),
            columnWidths: const {0: pw.FlexColumnWidth(3), 1: pw.FlexColumnWidth(1.5), 2: pw.FlexColumnWidth(3)},
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: _celeste),
                children: [_celda('INSTITUCION', negrita: true, centrado: true), _celda('MOVIL', negrita: true, centrado: true), _celda('A CARGO DE', negrita: true, centrado: true)],
              ),
              ...d.instituciones.map((i) => pw.TableRow(children: [_celda(i.institucion), _celda(i.movil), _celda(i.aCargo)])),
            ],
          ),
          pw.SizedBox(height: 6),

          // ---- Relato ----
          _cabecera('RELATO DE LA EMERGENCIA'),
          _bloqueTexto(d.relato, altoMinimo: 110),
          pw.SizedBox(height: 6),

          // ---- Afectados ----
          _cabecera('DATOS DE AFECTADOS (NOMBRES, RUT, PATENTES, NUMERO DIR, S.A O AMB DE TRASLADO, ETC)'),
          _bloqueTexto(d.afectados, altoMinimo: 50),

          // ---- Testigos (opcional) ----
          if (d.testigos.isNotEmpty) ...[
            pw.SizedBox(height: 6),
            _cabecera('DATOS DE TESTIGOS VOLUNTARIOS EN EL LUGAR'),
            pw.Table(
              border: pw.TableBorder.all(color: _borde, width: 0.6),
              columnWidths: const {0: pw.FlexColumnWidth(3), 1: pw.FlexColumnWidth(2)},
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: _celeste),
                  children: [_celda('NOMBRE', negrita: true, centrado: true), _celda('RUT', negrita: true, centrado: true)],
                ),
                ...d.testigos.map((t) => pw.TableRow(children: [_celda(t.nombre), _celda(t.rut)])),
              ],
            ),
          ],
          if (d.declaracionTestigos.trim().isNotEmpty) ...[
            pw.SizedBox(height: 6),
            _cabecera('DECLARACION DE TESTIGOS'),
            _bloqueTexto(d.declaracionTestigos, altoMinimo: 60),
          ],
          pw.SizedBox(height: 6),

          // ---- Croquis (opcional, puede tener varias fotos) ----
          if (d.croquis.isNotEmpty) ...[
            _cabecera('CROQUIS (caracteristicas clave de la situacion, distribucion del inmueble, posicion de vehiculos, imagen inicial y final, etc.)'),
            for (var i = 0; i < d.croquis.length; i++) ...[
              pw.Container(
                width: double.infinity,
                height: 280,
                decoration: pw.BoxDecoration(border: _bordeFino),
                padding: const pw.EdgeInsets.all(4),
                child: pw.Image(pw.MemoryImage(d.croquis[i]), fit: pw.BoxFit.contain),
              ),
              if (d.croquis.length > 1)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 1, bottom: 4),
                  child: pw.Text('Imagen ${i + 1} de ${d.croquis.length}', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
                ),
            ],
            pw.SizedBox(height: 6),
          ],

          // ---- Asistencia ----
          _cabecera('ASISTENCIA'),
          pw.Table(
            border: pw.TableBorder.all(color: _borde, width: 0.6),
            columnWidths: const {0: pw.FlexColumnWidth(1.4), 1: pw.FlexColumnWidth(3.5), 2: pw.FlexColumnWidth(2)},
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: _celeste),
                children: [
                  _celda('N DE VOLUNTARIO', negrita: true, centrado: true),
                  _celda('NOMBRE', negrita: true, centrado: true),
                  _celda('CARRO', negrita: true, centrado: true),
                ],
              ),
              ...d.asistentes.map((a) => pw.TableRow(children: [_celda(a.numeroVoluntario), _celda(a.nombre), _celda(a.carro)])),
            ],
          ),
        ],
      ),
    );

    return doc.save();
  }

  // ---------------- helpers de dibujo ----------------

  static pw.Widget _cabecera(String texto) => pw.Container(
        width: double.infinity,
        color: _celeste,
        padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 4),
        child: pw.Text(texto, textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
      );

  static pw.Widget _celda(String texto, {bool negrita = false, bool centrado = false}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 4),
        child: pw.Text(
          texto,
          textAlign: centrado ? pw.TextAlign.center : pw.TextAlign.left,
          style: pw.TextStyle(fontSize: 9, fontWeight: negrita ? pw.FontWeight.bold : pw.FontWeight.normal),
        ),
      );

  static pw.Widget _bloqueTexto(String texto, {double altoMinimo = 40}) => pw.Container(
        width: double.infinity,
        constraints: pw.BoxConstraints(minHeight: altoMinimo),
        decoration: pw.BoxDecoration(border: _bordeFino),
        padding: const pw.EdgeInsets.all(5),
        child: pw.Text(texto, style: const pw.TextStyle(fontSize: 9.5, lineSpacing: 2)),
      );

  // Una fila de la cabecera de datos: lista de (etiqueta | valor) con bordes.
  // Usa pw.Table (calcula el alto de cada fila); un Row con "stretch" dentro de
  // una MultiPage pide altura infinita y rompe la generación del PDF.
  static pw.Widget _fila(List<_Celda> celdas, {bool alinearDerecha = false}) {
    final tabla = pw.Table(
      border: pw.TableBorder.all(color: _borde, width: 0.6),
      columnWidths: {
        for (var i = 0; i < celdas.length; i++) i: pw.FlexColumnWidth(celdas[i].flex),
      },
      children: [
        pw.TableRow(
          children: celdas
              .map((c) => pw.Container(
                    color: c.esEtiqueta ? _celeste : null,
                    padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 4),
                    alignment: c.esEtiqueta ? pw.Alignment.center : pw.Alignment.centerLeft,
                    child: pw.Text(
                      c.texto,
                      style: pw.TextStyle(fontSize: 9, fontWeight: c.esEtiqueta ? pw.FontWeight.bold : pw.FontWeight.normal),
                    ),
                  ))
              .toList(),
        ),
      ],
    );
    if (!alinearDerecha) return tabla;
    // FECHA: ocupa solo la mitad derecha, como en el libro.
    return pw.Row(children: [pw.Expanded(child: pw.SizedBox()), pw.Expanded(child: tabla)]);
  }

  static _Celda _etiqueta(String t, {double flex = 1.3}) => _Celda(t, flex, true);
  static _Celda _valor(String t, {double flex = 2.2}) => _Celda(t, flex, false);
}

class _Celda {
  final String texto;
  final double flex;
  final bool esEtiqueta;
  const _Celda(this.texto, this.flex, this.esEtiqueta);
}
