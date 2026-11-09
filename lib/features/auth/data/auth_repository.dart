import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/api/api_client.dart';

class Employee {
  const Employee({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    this.documentId,
  });

  factory Employee.fromJson(Map<String, dynamic> j) => Employee(
    id: j['id'] as String,
    email: j['email'] as String,
    fullName: j['fullName'] as String,
    role: j['role'] as String,
    documentId: j['documentId'] as String?,
  );

  final String id;
  final String email;
  final String fullName;
  final String role;

  /// Documento de identidad, o null si RRHH no lo registró.
  final String? documentId;

  String get firstName => fullName.split(' ').first;
  bool get isHr => role == 'hr' || role == 'admin';

  String get roleLabel => switch (role) {
    'admin' => 'Administrador',
    'hr' => 'Recursos Humanos',
    'manager' => 'Jefatura',
    _ => 'Empleado',
  };
}

class Session {
  const Session({required this.token, required this.employee});
  final String token;
  final Employee employee;
}

abstract class AuthRepository {
  Future<Session> login(String email, String password);

  /// Sesión guardada y todavía válida, o null.
  Future<Session?> restore();

  Future<void> logout();
}

class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository(this._api, [FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static const _tokenKey = 'access_token';
  final ApiClient _api;
  final FlutterSecureStorage _storage;

  @override
  Future<Session> login(String email, String password) async {
    final res = await _api.post('/auth/login', {
      'email': email.trim(),
      'password': password,
    });
    final token = res['accessToken'] as String;
    await _storage.write(key: _tokenKey, value: token);
    return Session(
      token: token,
      employee: Employee.fromJson(res['employee'] as Map<String, dynamic>),
    );
  }

  @override
  Future<Session?> restore() async {
    final token = await _storage.read(key: _tokenKey);
    if (token == null) return null;
    try {
      final me = await _api.get('/auth/me', token: token);
      return Session(token: token, employee: Employee.fromJson(me));
    } on ApiException catch (e) {
      // Solo se descarta el token si el servidor lo rechazó; sin red se conserva.
      if (e.isUnauthorized) await _storage.delete(key: _tokenKey);
      return null;
    }
  }

  @override
  Future<void> logout() => _storage.delete(key: _tokenKey);
}
