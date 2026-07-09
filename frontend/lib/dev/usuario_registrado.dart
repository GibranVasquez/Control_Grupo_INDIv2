import '../models/enums.dart';

/// Tipo de unidad elegido en el registro. Distinto de [TipoUnidad] (modelo real):
/// aquí distinguimos también la Pipa, que abastece a la maquinaria en campo.
enum TipoVehiculoDemo {
  camioneta,
  maquinaria,
  pipa;

  String get etiqueta => switch (this) {
        TipoVehiculoDemo.camioneta => 'Camioneta',
        TipoVehiculoDemo.maquinaria => 'Maquinaria',
        TipoVehiculoDemo.pipa => 'Pipa',
      };

  /// Solo la camioneta permite elegir el tipo de combustible; maquinaria y pipas
  /// siempre operan con diésel, así que el combustible se asigna automáticamente.
  bool get permiteElegirCombustible => this == TipoVehiculoDemo.camioneta;

  TipoCombustible get combustiblePredeterminado =>
      permiteElegirCombustible ? TipoCombustible.magna : TipoCombustible.diesel;

  /// Maquinaria y pipas no siempre tienen placas: se identifican por número económico.
  String get etiquetaIdentificador =>
      this == TipoVehiculoDemo.camioneta ? 'Placas del vehículo' : 'Número económico';

  String get hintIdentificador =>
      this == TipoVehiculoDemo.camioneta ? 'Ej. GX-42-118' : 'Ej. CAT-140-03';
}

/// Usuario creado desde el registro (`register_page.dart`). Vive únicamente en memoria
/// mientras no hay backend de altas de usuario: se guarda en [DatosDemo.usuariosRegistrados].
class UsuarioRegistrado {
  UsuarioRegistrado({
    required this.nombres,
    required this.apellidoPaterno,
    required this.apellidoMaterno,
    required this.edad,
    required this.telefono,
    required this.usuario,
    required this.password,
    required this.obraId,
    required this.ingenieroId,
    required this.lugarCarga,
    required this.tipoVehiculo,
    required this.tipoCombustible,
    required this.identificadorVehiculo,
  });

  final String nombres;
  final String apellidoPaterno;
  final String apellidoMaterno;
  final int edad;
  final String telefono;

  final String usuario;
  final String password;

  final String obraId;
  final String ingenieroId;
  final String lugarCarga;

  final TipoVehiculoDemo tipoVehiculo;
  final TipoCombustible tipoCombustible;

  /// Placas (camioneta) o número económico (maquinaria/pipa), según [tipoVehiculo].
  final String identificadorVehiculo;

  String get nombreCompleto => '$nombres $apellidoPaterno $apellidoMaterno';
}
