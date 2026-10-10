import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Catálogo fijo de ítems por categoría, igual al formulario en papel.
/// Si tu compañía usa otra lista, solo edita este mapa.
const Map<String, List<String>> catalogoEpp = {
  'ESTRUCTURAL': [
    'CASCO F1 / BULLARD',
    'CASACA NORMADA',
    'JARDINERA NORMADA',
    'BOTAS DE TRABAJO NORMADA',
    'GUANTES NORMADOS',
    'ESCLAVINA',
  ],
  'RESCATE': [
    'CASACA DE RESCATE',
    'UNIFORME MULTI ROL',
    'GUANTES DE EXTRICACIÓN',
    'CASCO DE RESCATE',
    'PANTALÓN RESCATE',
  ],
  'FORESTAL': [
    'UNIFORME MULTI ROL',
    'ESCLAVINA',
    'BOTAS HAIX',
    'CASCO',
  ],
  'ACCESORIOS': [
    'PORTÁTIL EP 450 / DGP 8050',
    'CARGADOR',
    'BATERÍA ADICIONAL',
    'PANTALÓN DE CUARTEL',
    'POLERA INSTITUCIONAL',
    'LINTERNA ÁNGULO RECTO',
  ],
};

/// Resultado del checklist para un ítem puntual del catálogo.
class ItemEntregaEpp {
  final String nombre;
  final bool entregado; // true = SI, false = NO
  final String observacion;
  ItemEntregaEpp(this.nombre, this.entregado, this.observacion);
}

class EntregaEppPdfService {
  static Future<Uint8List> generar({
    required String companiaNombre,
    required String voluntarioNombre,
    required String run,
    required String nRegistro,
    required String fecha, // dd/mm/aaaa
    required Map<String, List<ItemEntregaEpp>> itemsPorCategoria,
    required String nombreCapitan,
  }) async {
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Center(
            child: pw.Column(children: [
              pw.Text('Registro de entrega', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.Text('Equipo de protección personal', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Text(companiaNombre, style: const pw.TextStyle(fontSize: 11)),
            ]),
          ),
          pw.SizedBox(height: 16),

          _filaDato('NOMBRE VOLUNTARIO', voluntarioNombre),
          _filaDato('R.U.N.', run),
          _filaDato('N° DE REGISTRO', nRegistro),
          _filaDato('FECHA', fecha),
          pw.SizedBox(height: 14),

          ...itemsPorCategoria.entries.expand((entry) => [
                _tablaCategoria(entry.key, entry.value),
                pw.SizedBox(height: 14),
              ]),

          pw.SizedBox(height: 8),
          pw.Text(
            'COMPROMISO: Me comprometo a cuidar y mantener en buen estado el equipo de '
            'protección personal. Cualquier pérdida o imprevisto no justificado, deberé '
            'comunicarlo, quedando a disposición y decisión de los oficiales operativos la '
            'devolución de los implementos de seguridad, siendo estos de propiedad del '
            '$companiaNombre.',
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, lineSpacing: 3),
          ),
          pw.SizedBox(height: 48),

          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _firma(nombreCapitan, 'CAPITÁN'),
              _firma(voluntarioNombre, 'NOMBRE Y FIRMA\nVOLUNTARIO'),
            ],
          ),
        ],
      ),
    );

    return doc.save();
  }

  static pw.Widget _filaDato(String label, String valor) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(children: [
        pw.SizedBox(width: 140, child: pw.Text(label, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 0.5))),
            child: pw.Text(valor, style: const pw.TextStyle(fontSize: 10)),
          ),
        ),
      ]),
    );
  }

  static pw.Widget _tablaCategoria(String categoria, List<ItemEntregaEpp> items) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Container(
          color: PdfColors.grey300,
          padding: const pw.EdgeInsets.symmetric(vertical: 4),
          child: pw.Center(child: pw.Text(categoria, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold))),
        ),
        pw.TableHelper.fromTextArray(
          border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey600),
          cellStyle: const pw.TextStyle(fontSize: 9),
          headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
          columnWidths: {
            0: const pw.FlexColumnWidth(4),
            1: const pw.FlexColumnWidth(1),
            2: const pw.FlexColumnWidth(1),
            3: const pw.FlexColumnWidth(3),
          },
          headers: ['', 'SI', 'NO', 'OBSERVACIÓN'],
          data: items
              .map((i) => [i.nombre, i.entregado ? 'X' : '', i.entregado ? '' : 'X', i.observacion])
              .toList(),
        ),
      ],
    );
  }

  static pw.Widget _firma(String nombre, String cargo) {
    return pw.Column(children: [
      pw.Container(width: 160, height: 1, color: PdfColors.black, margin: const pw.EdgeInsets.only(bottom: 4)),
      pw.Text(nombre.isNotEmpty ? nombre : '_______________', style: const pw.TextStyle(fontSize: 10)),
      pw.Text(cargo, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 9)),
    ]);
  }
}
