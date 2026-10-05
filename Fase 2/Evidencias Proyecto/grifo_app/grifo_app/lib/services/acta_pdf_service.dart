import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../widgets/firma_dialog.dart';

/// Un asistente a la reunión (nombre + cargo).
class ActaAsistente {
  final String nombre;
  final String cargo;
  ActaAsistente(this.nombre, this.cargo);
}

/// Un tema/acuerdo tratado en la reunión.
class ActaAcuerdo {
  final String tema;
  final String detalle;
  ActaAcuerdo(this.tema, this.detalle);
}

/// Genera el PDF del acta, imitando la estructura del libro manuscrito:
/// encabezado, cuerpo con asistentes, acuerdos y firmas al final.
class ActaPdfService {
  static Future<Uint8List> generar({
    required String tituloReunion,
    required String companiaNombre,
    required String fecha, // dd/mm/aaaa
    required String horaInicio,
    String? horaTermino,
    required String lugar,
    required String tipoReunion,
    required String presididaPor,
    required List<ActaAsistente> asistentes,
    required List<ActaAcuerdo> acuerdos,
    FirmaData? firmaSuperintendente,
    FirmaData? firmaSecretario,
  }) async {
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(36),
        build: (context) => [
          pw.Center(
            child: pw.Text(
              'Acta de Reunión $tipoReunion de Directorio de\n$companiaNombre',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 18),
          pw.Text(
            'En ${lugar.isNotEmpty ? lugar : companiaNombre}, siendo las $horaInicio horas, '
            'del día $fecha, se llevó a efecto la Reunión $tipoReunion de Directorio '
            'de $companiaNombre, presidida por $presididaPor, y con la asistencia de '
            'los siguientes Oficiales Generales y Directores.',
            style: const pw.TextStyle(fontSize: 11, lineSpacing: 3),
          ),
          pw.SizedBox(height: 16),

          pw.Text('Asistentes', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Table(
            border: null,
            columnWidths: const {0: pw.FlexColumnWidth(2), 1: pw.FlexColumnWidth(2)},
            children: asistentes
                .map((a) => pw.TableRow(children: [
                      pw.Padding(padding: const pw.EdgeInsets.only(bottom: 4), child: pw.Text(a.nombre, style: const pw.TextStyle(fontSize: 11))),
                      pw.Padding(padding: const pw.EdgeInsets.only(bottom: 4), child: pw.Text(a.cargo, style: const pw.TextStyle(fontSize: 11))),
                    ]))
                .toList(),
          ),
          pw.SizedBox(height: 18),

          pw.Text('Temas tratados / Acuerdos', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          ...acuerdos.expand((a) => [
                pw.Text(a.tema, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 3),
                pw.Text(a.detalle, style: const pw.TextStyle(fontSize: 11, lineSpacing: 3)),
                pw.SizedBox(height: 12),
              ]),

          pw.SizedBox(height: 10),
          pw.Text(
            'No habiendo otros temas que tratar${horaTermino != null ? ', y siendo las $horaTermino horas,' : ','} '
            'se da por terminada la presente Reunión $tipoReunion de Directorio.',
            style: const pw.TextStyle(fontSize: 11, lineSpacing: 3),
          ),
          pw.SizedBox(height: 48),

          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _firma(firmaSuperintendente, 'Superintendente'),
              _firma(firmaSecretario, 'Secretario/a General'),
            ],
          ),
        ],
      ),
    );

    return doc.save();
  }

  static pw.Widget _firma(FirmaData? firma, String cargo) {
    if (firma == null) {
      return pw.Column(children: [
        pw.Container(width: 160, height: 1, color: PdfColors.black, margin: const pw.EdgeInsets.only(bottom: 4)),
        const pw.Text('_______________', style: pw.TextStyle(fontSize: 11)),
        pw.Text(cargo, style: const pw.TextStyle(fontSize: 10)),
      ]);
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        if (firma.esFoto && firma.fotoBytes != null)
          pw.Container(
            height: 60,
            margin: const pw.EdgeInsets.only(bottom: 4),
            child: pw.Image(pw.MemoryImage(firma.fotoBytes!), fit: pw.BoxFit.contain),
          )
        else
          pw.Container(width: 160, height: 1, color: PdfColors.black, margin: const pw.EdgeInsets.only(bottom: 4)),
        pw.Text(firma.nombreVerificado, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
        if (!firma.esFoto && firma.rut != null) pw.Text('RUT: ${firma.rut}', style: const pw.TextStyle(fontSize: 9)),
        pw.Text(cargo, style: const pw.TextStyle(fontSize: 10)),
        pw.Text('Identidad verificada ✓', style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600, fontStyle: pw.FontStyle.italic)),
      ],
    );
  }
}
