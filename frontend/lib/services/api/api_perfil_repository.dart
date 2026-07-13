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
/// - [actualizarActivo]: API REST directa (`PUT /perfiles/:id/activo`). No
///   pasa por PowerSync (sync-config.yaml solo replica `perfiles` de
///   solo lectura); el cambio llega de vuelta al catálogo local en la
///   siguiente sincronización normal, igual que vehiculos.crear/actualizar.
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
    required String numeroEmpleado,
    required String password,
  }) async {
    final respuesta = await apiClient.dio.post<Map<String, dynamic>>(
      '/auth/login',
      data: {'numero_empleado': numeroEmpleado, 'password': password},
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
  Future<Perfil> crear({
    required String nombreCompleto,
    required String numeroEmpleado,
    required String password,
    required String obraId,
    String? vehiculoId,
    String? area,
  }) async {
    final respuesta = await apiClient.dio.post<Map<String, dynamic>>('/perfiles', data: {
      'nombre_completo': nombreCompleto,
      'numero_empleado': numeroEmpleado,
      'password': password,
      'obra_id': obraId,
      'vehiculo_id': ?vehiculoId,
      'area': ?area,
    });
    return Perfil.fromJson(respuesta.data!['perfil'] as Map<String, dynamic>);
  }

  Map<String, dynamic> _filaAJson(Map<String, dynamic> fila) => {
        'id': fila['id'],
        'auth_user_id': fila['auth_user_id'],
        'numero_empleado': fila['numero_empleado'],
        'nombre_completo': fila['nombre_completo'],
        'rol': fila['rol'],
        'obra_id': fila['obra_id'],
        'vehiculo_id': fila['vehiculo_id'],
        'area': fila['area'],
        'activo': fila['activo'] == 1,
      };
}
