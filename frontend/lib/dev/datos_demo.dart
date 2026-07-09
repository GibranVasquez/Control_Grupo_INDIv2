import '../models/models.dart';

/// Datos ilustrativos para maquetar la UI mientras no hay repositorios reales conectados.
/// Borrar este archivo (y sus usos) en cuanto las pantallas lean de Supabase/PowerSync.
class DatosDemo {
  DatosDemo._();

  static final perfilChofer = Perfil(
    id: 'perfil-german',
    authUserId: 'auth-german',
    numeroEmpleado: 'INDI-04871',
    nombreCompleto: 'Germán Hernández',
    rol: RolUsuario.chofer,
    obraId: 'obra-tren-golfo',
    activo: true,
  );

  static final vehiculoAsignado = Vehiculo(
    id: 'vehiculo-1',
    placa: 'GX-42-118',
    marca: 'Ford',
    modelo: 'F-150',
    anio: 2022,
    tipoCombustible: TipoCombustible.magna,
    topeLitrosSemanal: 240,
    obraId: 'obra-tren-golfo',
    estado: 'activo',
  );

  static final List<SolicitudAutorizacion> solicitudesDeGerman = [
    SolicitudAutorizacion(
      id: 'sol-3',
      choferId: perfilChofer.id,
      vehiculoId: vehiculoAsignado.id,
      obraId: 'obra-tren-golfo',
      litrosSolicitados: 40,
      estado: EstadoSolicitud.pendiente,
      creadoEn: DateTime(2026, 7, 8, 18, 4),
      creadoOffline: false,
    ),
    SolicitudAutorizacion(
      id: 'sol-2',
      choferId: perfilChofer.id,
      vehiculoId: vehiculoAsignado.id,
      obraId: 'obra-tren-golfo',
      litrosSolicitados: 35,
      litrosAutorizados: 30,
      comentario: 'Ya casi llegabas al tope de la semana, se ajustó a lo disponible.',
      estado: EstadoSolicitud.autorizado,
      resueltoPor: 'Ing. Paola Reyes',
      resueltoEn: DateTime(2026, 7, 7, 8, 12),
      creadoEn: DateTime(2026, 7, 6, 19, 40),
      creadoOffline: false,
    ),
    SolicitudAutorizacion(
      id: 'sol-1',
      choferId: perfilChofer.id,
      vehiculoId: vehiculoAsignado.id,
      obraId: 'obra-tren-golfo',
      litrosSolicitados: 50,
      estado: EstadoSolicitud.cargado,
      resueltoPor: 'Ing. Paola Reyes',
      resueltoEn: DateTime(2026, 7, 5, 7, 55),
      creadoEn: DateTime(2026, 7, 4, 20, 10),
      creadoOffline: false,
    ),
  ];

  static const precioMagnaPorLitro = 23.99;

  static final perfilesChoferes = <Perfil>[
    perfilChofer,
    Perfil(
      id: 'perfil-lidia',
      authUserId: 'auth-lidia',
      numeroEmpleado: 'INDI-05012',
      nombreCompleto: 'Lidia Mendoza',
      rol: RolUsuario.chofer,
      obraId: 'obra-tren-golfo',
      activo: true,
    ),
    Perfil(
      id: 'perfil-oscar',
      authUserId: 'auth-oscar',
      numeroEmpleado: 'INDI-05130',
      nombreCompleto: 'Óscar Villareal',
      rol: RolUsuario.chofer,
      obraId: 'obra-tren-golfo',
      activo: true,
    ),
  ];

  static final vehiculosObra = <Vehiculo>[
    vehiculoAsignado,
    Vehiculo(
      id: 'vehiculo-2',
      placa: 'GX-88-207',
      marca: 'Chevrolet',
      modelo: 'Silverado',
      anio: 2021,
      tipoCombustible: TipoCombustible.diesel,
      topeLitrosSemanal: 300,
      obraId: 'obra-tren-golfo',
      estado: 'activo',
    ),
    Vehiculo(
      id: 'vehiculo-3',
      placa: 'GX-19-350',
      marca: 'Nissan',
      modelo: 'NP300',
      anio: 2020,
      tipoCombustible: TipoCombustible.magna,
      topeLitrosSemanal: 180,
      obraId: 'obra-tren-golfo',
      estado: 'activo',
    ),
    Vehiculo(
      id: 'maquinaria-1',
      placa: 'MAQ-CAT-320',
      marca: 'Caterpillar',
      modelo: '320 Excavadora',
      anio: 2019,
      tipoCombustible: TipoCombustible.diesel,
      topeLitrosSemanal: 500,
      obraId: 'obra-tren-golfo',
      estado: 'activo',
      tipoUnidad: TipoUnidad.maquinaria,
    ),
  ];

  static final List<SolicitudAutorizacion> solicitudesPendientesObra = [
    SolicitudAutorizacion(
      id: 'sol-3',
      choferId: perfilChofer.id,
      vehiculoId: vehiculosObra[0].id,
      obraId: 'obra-tren-golfo',
      litrosSolicitados: 40,
      estado: EstadoSolicitud.pendiente,
      creadoEn: DateTime(2026, 7, 8, 18, 4),
      creadoOffline: false,
    ),
    SolicitudAutorizacion(
      id: 'sol-4',
      choferId: perfilesChoferes[1].id,
      vehiculoId: vehiculosObra[1].id,
      obraId: 'obra-tren-golfo',
      litrosSolicitados: 60,
      comentario: 'Viaje doble a la planta de agregados por reprogramación de la cuadrilla.',
      estado: EstadoSolicitud.pendiente,
      creadoEn: DateTime(2026, 7, 8, 17, 20),
      creadoOffline: false,
    ),
    SolicitudAutorizacion(
      id: 'sol-5',
      choferId: perfilesChoferes[2].id,
      vehiculoId: vehiculosObra[2].id,
      obraId: 'obra-tren-golfo',
      litrosSolicitados: 25,
      estado: EstadoSolicitud.pendiente,
      creadoEn: DateTime(2026, 7, 8, 16, 55),
      creadoOffline: false,
    ),
  ];

  static const consumoSemanalVehiculo1 = VistaConsumoVehiculoSemanal(
    vehiculoId: 'vehiculo-1',
    litrosConsumidos: 165,
    topeLitrosSemanal: 240,
  );

  static const presupuestoSemanalObra = 1000000.0;
  static const presupuestoEjercidoObra = 700000.0;

  static final concentradoCargasObra = <VistaConcentradoCargas>[
    VistaConcentradoCargas(
      cargaId: 'carga-1',
      fecha: DateTime(2026, 7, 7),
      responsable: 'Germán Hernández',
      vehiculoDescripcion: 'Ford F-150',
      placa: 'GX-42-118',
      km: 182,
      litros: 35,
      rendimientoKmL: 5.2,
      precioPorLitro: precioMagnaPorLitro,
      tipoCombustible: TipoCombustible.magna,
      importe: 35 * precioMagnaPorLitro,
      fotoTicketUrl: 'https://example.com/ticket-1.jpg',
      alertaRendimiento: AlertaRendimiento.bajo,
    ),
    VistaConcentradoCargas(
      cargaId: 'carga-2',
      fecha: DateTime(2026, 7, 6),
      responsable: 'Óscar Villareal',
      vehiculoDescripcion: 'Nissan NP300',
      placa: 'GX-19-350',
      km: 240,
      litros: 22,
      rendimientoKmL: 10.9,
      precioPorLitro: precioMagnaPorLitro,
      tipoCombustible: TipoCombustible.magna,
      importe: 22 * precioMagnaPorLitro,
      fotoTicketUrl: 'https://example.com/ticket-2.jpg',
      alertaRendimiento: AlertaRendimiento.normal,
    ),
    VistaConcentradoCargas(
      cargaId: 'carga-3',
      fecha: DateTime(2026, 7, 6),
      responsable: 'Lidia Mendoza',
      vehiculoDescripcion: 'Chevrolet Silverado',
      placa: 'GX-88-207',
      km: 58,
      litros: 28,
      rendimientoKmL: 2.1,
      precioPorLitro: 28.0,
      tipoCombustible: TipoCombustible.diesel,
      importe: 28 * 28.0,
      alertaRendimiento: AlertaRendimiento.revisar,
    ),
    VistaConcentradoCargas(
      cargaId: 'carga-4',
      fecha: DateTime(2026, 6, 18),
      responsable: 'Germán Hernández',
      vehiculoDescripcion: 'Ford F-150',
      placa: 'GX-42-118',
      km: 210,
      litros: 38,
      rendimientoKmL: 5.5,
      precioPorLitro: precioMagnaPorLitro,
      tipoCombustible: TipoCombustible.magna,
      importe: 38 * precioMagnaPorLitro,
      fotoTicketUrl: 'https://example.com/ticket-4.jpg',
      alertaRendimiento: AlertaRendimiento.normal,
    ),
    VistaConcentradoCargas(
      cargaId: 'carga-5',
      fecha: DateTime(2026, 5, 9),
      responsable: 'Óscar Villareal',
      vehiculoDescripcion: 'Nissan NP300',
      placa: 'GX-19-350',
      km: 195,
      litros: 30,
      rendimientoKmL: 6.5,
      precioPorLitro: precioMagnaPorLitro,
      tipoCombustible: TipoCombustible.magna,
      importe: 30 * precioMagnaPorLitro,
      fotoTicketUrl: 'https://example.com/ticket-5.jpg',
      alertaRendimiento: AlertaRendimiento.normal,
    ),
    VistaConcentradoCargas(
      cargaId: 'carga-6',
      fecha: DateTime(2025, 11, 21),
      responsable: 'Lidia Mendoza',
      vehiculoDescripcion: 'Chevrolet Silverado',
      placa: 'GX-88-207',
      km: 240,
      litros: 45,
      rendimientoKmL: 5.3,
      precioPorLitro: 27.5,
      tipoCombustible: TipoCombustible.diesel,
      importe: 45 * 27.5,
      fotoTicketUrl: 'https://example.com/ticket-6.jpg',
      alertaRendimiento: AlertaRendimiento.normal,
    ),
  ];

  static final obras = <Obra>[
    Obra(
      id: 'obra-tren-golfo',
      nombre: 'Tren Golfo de México',
      ubicacion: 'Coatzacoalcos, Ver.',
      estado: 'activa',
      fechaInicio: DateTime(2025, 1, 13),
    ),
  ];

  static final perfilAdministrativo = Perfil(
    id: 'perfil-paola',
    authUserId: 'auth-paola',
    numeroEmpleado: 'INDI-01120',
    nombreCompleto: 'Ing. Paola Reyes',
    rol: RolUsuario.administrativo,
    obraId: 'obra-tren-golfo',
    activo: true,
  );

  static final perfilFinanzas = Perfil(
    id: 'perfil-fernando',
    authUserId: 'auth-fernando',
    numeroEmpleado: 'INDI-00042',
    nombreCompleto: 'Lic. Fernando Aguilar',
    rol: RolUsuario.finanzas,
    activo: true,
  );

  static final perfilesTodos = <Perfil>[
    ...perfilesChoferes,
    perfilAdministrativo,
    perfilFinanzas,
  ];

  static final precios = <PrecioCombustible>[
    PrecioCombustible(
      id: 'precio-magna',
      tipoCombustible: TipoCombustible.magna,
      precioPorLitro: precioMagnaPorLitro,
      vigenteDesde: DateTime(2026, 7, 1),
    ),
    PrecioCombustible(
      id: 'precio-premium',
      tipoCombustible: TipoCombustible.premium,
      precioPorLitro: 25.79,
      vigenteDesde: DateTime(2026, 7, 1),
    ),
    PrecioCombustible(
      id: 'precio-diesel',
      tipoCombustible: TipoCombustible.diesel,
      precioPorLitro: 28.0,
      vigenteDesde: DateTime(2026, 7, 1),
    ),
  ];

  static final semanaActual = SemanaOperativa(
    id: 'semana-28',
    periodoInicio: DateTime(2026, 7, 6),
    periodoFin: DateTime(2026, 7, 12),
    estado: 'abierta',
  );

  static final resumenFinancieroObra = <VistaResumenFinancieroSemanal>[
    VistaResumenFinancieroSemanal(
      semanaId: 'semana-27',
      numeroSemana: 27,
      periodoInicio: DateTime(2026, 6, 29),
      periodoFin: DateTime(2026, 7, 5),
      solicitado: 210000,
      consumo: 198500,
      deposito: 210000,
      saldoAFavor: 11500,
      estatus: 'pagado',
    ),
    VistaResumenFinancieroSemanal(
      semanaId: 'semana-28',
      numeroSemana: 28,
      periodoInicio: DateTime(2026, 7, 6),
      periodoFin: DateTime(2026, 7, 12),
      solicitado: 220000,
      consumo: 154200,
      deposito: 0,
      saldoAFavor: 11500,
      estatus: 'solicitado',
    ),
    VistaResumenFinancieroSemanal(
      semanaId: 'semana-24',
      numeroSemana: 24,
      periodoInicio: DateTime(2026, 6, 8),
      periodoFin: DateTime(2026, 6, 14),
      solicitado: 195000,
      consumo: 180200,
      deposito: 195000,
      saldoAFavor: 14800,
      estatus: 'pagado',
    ),
    VistaResumenFinancieroSemanal(
      semanaId: 'semana-19',
      numeroSemana: 19,
      periodoInicio: DateTime(2026, 5, 4),
      periodoFin: DateTime(2026, 5, 10),
      solicitado: 205000,
      consumo: 199000,
      deposito: 205000,
      saldoAFavor: 6000,
      estatus: 'pagado',
    ),
    VistaResumenFinancieroSemanal(
      semanaId: 'semana-47-2025',
      numeroSemana: 47,
      periodoInicio: DateTime(2025, 11, 17),
      periodoFin: DateTime(2025, 11, 23),
      solicitado: 180000,
      consumo: 172500,
      deposito: 180000,
      saldoAFavor: 7500,
      estatus: 'pagado',
    ),
  ];
}
