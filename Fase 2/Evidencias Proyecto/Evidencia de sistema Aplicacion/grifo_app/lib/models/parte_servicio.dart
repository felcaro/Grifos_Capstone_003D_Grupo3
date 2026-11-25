import 'dart:typed_data';

/// Una fila de "EN EL LUGAR": institución presente, su móvil y quién está a cargo.
class ParteInstitucion {
  final String institucion;
  final String movil;
  final String aCargo;
  const ParteInstitucion(this.institucion, this.movil, this.aCargo);
}

/// Un testigo voluntario (nombre + RUT).
class ParteTestigo {
  final String nombre;
  final String rut;
  const ParteTestigo(this.nombre, this.rut);
}

/// Un voluntario que asistió, con el carro en que fue.
class ParteAsistente {
  final String numeroVoluntario;
  final String nombre;
  final String carro;
  const ParteAsistente({required this.numeroVoluntario, required this.nombre, required this.carro});
}

/// Todos los datos del Parte de Servicio, listos para generar el PDF.
class ParteServicioData {
  final String companiaNombre;
  final String fecha; // dd/mm/aaaa
  final String unidad;
  final String servicio;
  final String direccion;
  final String nombre;
  final String rut;
  final String nroObac;
  final String horaSalida;
  final String horaLlegada;
  final String odometroInicial;
  final String odometroFinal;
  final String clave60;
  final List<ParteInstitucion> instituciones;
  final String relato;
  final String afectados;
  final List<ParteTestigo> testigos; // opcional
  final String declaracionTestigos; // opcional
  final List<Uint8List> croquis; // opcional: 0 o más fotos
  final List<ParteAsistente> asistentes;

  const ParteServicioData({
    required this.companiaNombre,
    required this.fecha,
    required this.unidad,
    required this.servicio,
    required this.direccion,
    required this.nombre,
    required this.rut,
    required this.nroObac,
    required this.horaSalida,
    required this.horaLlegada,
    required this.odometroInicial,
    required this.odometroFinal,
    required this.clave60,
    required this.instituciones,
    required this.relato,
    required this.afectados,
    required this.testigos,
    required this.declaracionTestigos,
    required this.croquis,
    required this.asistentes,
  });
}
