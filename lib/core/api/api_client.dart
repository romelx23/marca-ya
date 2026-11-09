import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  ApiException(this.statusCode, this.message);
  final int statusCode;
  final String message;

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => message;
}

/// URL del backend. Se puede cambiar con `--dart-define=API_URL=https://...`.
String defaultApiUrl() {
  const fromEnv = String.fromEnvironment('API_URL');
  if (fromEnv.isNotEmpty) return fromEnv;
  // El emulador de Android ve el equipo anfitrión en 10.0.2.2.
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:3000';
  }
  return 'http://localhost:3000';
}

class ApiClient {
  ApiClient({required this.baseUrl, http.Client? client})
    : _http = client ?? http.Client();

  final String baseUrl;
  final http.Client _http;

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) async =>
      await _send(
            () => _http.post(
              Uri.parse('$baseUrl$path'),
              headers: _headers(token),
              body: jsonEncode(body),
            ),
          )
          as Map<String, dynamic>;

  Future<Map<String, dynamic>> get(String path, {String? token}) async =>
      await _send(
            () =>
                _http.get(Uri.parse('$baseUrl$path'), headers: _headers(token)),
          )
          as Map<String, dynamic>;

  /// Para endpoints que devuelven una lista JSON.
  Future<List<dynamic>> getList(String path, {String? token}) async =>
      await _send(
            () =>
                _http.get(Uri.parse('$baseUrl$path'), headers: _headers(token)),
          )
          as List<dynamic>;

  Map<String, String> _headers(String? token) => {
    'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };

  /// Devuelve el JSON decodificado (mapa o lista), o lanza [ApiException].
  Future<Object?> _send(Future<http.Response> Function() call) async {
    final http.Response res;
    try {
      res = await call().timeout(const Duration(seconds: 15));
    } on Exception {
      throw ApiException(0, 'No se pudo conectar con el servidor');
    }
    final decoded = res.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return decoded;
    }
    var message = 'Error ${res.statusCode}';
    if (decoded is Map && decoded['message'] != null) {
      final m = decoded['message'];
      message = m is List ? m.join('\n') : m.toString();
    }
    throw ApiException(res.statusCode, message);
  }
}
