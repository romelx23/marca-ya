import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../data/auth_repository.dart';

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(baseUrl: defaultApiUrl()),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => ApiAuthRepository(ref.watch(apiClientProvider)),
);

/// Estado de sesión: cargando al restaurar, null sin sesión, o la sesión activa.
final authControllerProvider = AsyncNotifierProvider<AuthController, Session?>(
  AuthController.new,
);

class AuthController extends AsyncNotifier<Session?> {
  @override
  Future<Session?> build() => ref.read(authRepositoryProvider).restore();

  /// Devuelve el mensaje de error, o null si el inicio de sesión fue correcto.
  Future<String?> login(String email, String password) async {
    try {
      final session = await ref
          .read(authRepositoryProvider)
          .login(email, password);
      state = AsyncData(session);
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (e) {
      // Errores no previstos (p. ej. al guardar el token): no deben dejar el login cargando.
      debugPrint('Login falló: $e');
      return 'No se pudo iniciar sesión. Intenta de nuevo.';
    }
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    state = const AsyncData(null);
  }
}
