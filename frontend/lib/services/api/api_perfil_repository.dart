import 'package:powersync/powersync.dart';

import '../../models/models.dart';
import '../perfil_repository.dart';
import 'api_client.dart';
import 'token_storage.dart';

/// Decisión de transporte para `perfiles`:
///
/// - [iniciarSesion] / [obtenerPerfilActual]: siempre API REST directa. El
///   login no puede pasar por PowerSync (no tiene su propio login: usa el
///   JWT que emite `POST /auth/login`, ver powersync_client.dart) y el
///   perfil propio se consulta fresco en cada `perfil-actual` para reflejar
///   de inmediato cambios de rol/obra/estado activo, sin depender de que ya
///   haya corrido una sincronización.
/// - [listarPorObra]: lectura del catálogo local de PowerSync. `perfiles` sí
///   está en sync-config.yaml para administrativo (su obra) y finanzas
///   (todas), que son los únicos roles que llaman a este método.
/// - [actualizarActivo] / [actualizar]: API REST directa (`PUT
///   /perfiles/:id/activo`, `PUT /perfiles/:id`). No pasan por PowerSync
///   (sync-config.yaml solo replica `perfiles` de solo lectura); el cambio
///   llega de vuelta al catálogo local en la siguiente sincronización normal,
///   igual que vehiculos.crear/actualizar.
class ApiPerfilRepository implements PerfilRepository {
  ApiPerfilRepository({
    required this.apiClient,
    required this.tokenStorage,
    required this.powerSyncDatabase,
  });

  final ApiClient apiClient;
  final TokenStorage tokenStorage;
  final PowerSyncDatabase powerSyncDatabase;

  @override
  Future<Perfil> iniciarSesion({
    required String usuario,
    required String password,
  }) async {
    final respuesta = await apiClient.dio.post<Map<String, dynamic>>(
      '/auth/login',
      data: {'usuario': usuario, 'password': password},
    );
    final cuerpo = respuesta.data!;
    await tokenStorage.guardar(cuerpo['token'] as String);
    return Perfil.fromJson(cuerpo['perfil'] as Map<String, dynamic>);
  }

  @override
  Future<Perfil> obtenerPerfilActual() async {
    final respuesta = await apiClient.dio.get<Map<String, dynamic>>('/auth/perfil-actual');
    return Perfil.fromJson(respuesta.data!['perfil'] as Map<String, dynamic>);
  }

  @override
  Future<List<Perfil>> listarPorObra(String obraId) async {
    final filas = await powerSyncDatabase.getAll(
      'SELECT * FROM perfiles WHERE obra_id = ?',
      [obraId],
    );
    return filas.map((fila) => Perfil.fromJson(_filaAJson(fila))).toList();
  }

  @override
  Future<List<Perfil>> listarTodos() async {
    final filas = await powerSyncDatabase.getAll('SELECT * FROM perfiles');
    return filas.map((fila) => Perfil.fromJson(_filaAJson(fila))).toList();
  }

  @override
  Future<void> actualizarActivo(String perfilId, bool activo) async {
    await apiClient.dio.put('/perfiles/$perfilId/activo', data: {'activo': activo});
  }

  @override
  Future<Perfil> actualizar({
    required String perfilId,
    required String obraId,
    String? nombreCompleto,
    String? correo,
    int? edad,
    String? area,
    String? vehiculoId,
  }) async {
    final respuesta = await apiClient.dio.put<Map<String, dynamic>>(
      '/perfiles/$perfilId',
      data: {
        'obra_id': obraId,
        'nombre_completo': ?nombreCompleto,
        'correo': ?correo,
        'edad': ?edad,
        'area': ?area,
        'vehiculo_id': ?vehiculoId,
      },
    );
    return Perfil.fromJson(respuesta.data!['perfil'] as Map<String, dynamic>);
  }

  @override
  Future<Perfil> registrarChofer({
    required String nombreCompleto,
    required String usuario,
    required String password,
    required String obraId,
    required String placa,
    required String tipoUnidad,
    required String tipoCombustible,
    String? correo,
    int? edad,
    String? area,
  }) async {
    final respuesta = await apiClient.dio.post<Map<String, dynamic>>(
      '/auth/registro-chofer',
      data: {
        'nombre_completo': nombreCompleto,
        'usuario': usuario,
        'password': password,
        'obra_id': obraId,
        'placa': placa,
        'tipo_unidad': tipoUnidad,
        'tipo_combustible': tipoCombustible,
        'correo': ?correo,
        'edad': ?edad,
        'area': ?area,
      },
    );
    final cuerpo = respuesta.data!;
    await tokenStorage.guardar(cuerpo['token'] as String);
    return Perfil.fromJson(cuerpo['perfil'] as Map<String, dynamic>);
  }

  @override
  Future<List<ObraOpcion>> obrasDisponibles() async {
    final respuesta = await apiClient.dio.get<Map<String, dynamic>>(
      '/auth/obras-disponibles',
    );
    final lista = respuesta.data!['obras'] as List<dynamic>;
    return lista
        .map((o) => ObraOpcion.fromJson(o as Map<String, dynamic>))
        .toList();
  }

  Map<String, dynamic> _filaAJson(Map<String, dynamic> fila) => {
        'id': fila['id'],
        'auth_user_id': fila['auth_user_id'],
        'usuario': fila['usuario'],
        'nombre_completo': fila['nombre_completo'],
        'rol': fila['rol'],
        'correo': fila['correo'],
        'edad': fila['edad'],
        'obra_id': fila['obra_id'],
        'vehiculo_id': fila['vehiculo_id'],
        'area': fila['area'],
        'activo': fila['activo'] == 1,
      };
}
