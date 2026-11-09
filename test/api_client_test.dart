import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:marca_ya/core/api/api_client.dart';
import 'package:marca_ya/features/auth/data/auth_repository.dart';

void main() {
  test('el login del backend se convierte en Employee con documento', () async {
    final client = ApiClient(
      baseUrl: 'http://api.test',
      client: MockClient(
        (req) async => http.Response(
          jsonEncode({
            'accessToken': 't',
            'employee': {
              'id': '1',
              'email': 'ana@test.local',
              'fullName': 'Ana Ruiz',
              'documentId': '71234567',
              'role': 'employee',
              'active': true,
              'createdAt': '2026-11-09T16:15:45.000Z',
            },
          }),
          200,
        ),
      ),
    );

    final res = await client.post('/auth/login', {
      'email': 'ana@test.local',
      'password': 'x',
    });
    final employee = Employee.fromJson(res['employee'] as Map<String, dynamic>);

    expect(res['accessToken'], 't');
    expect(employee.documentId, '71234567');
    expect(employee.roleLabel, 'Empleado');
  });

  test('getList decodifica una lista JSON', () async {
    final client = ApiClient(
      baseUrl: 'http://api.test',
      client: MockClient(
        (req) async => http.Response(
          jsonEncode([
            {'type': 'in', 'occurredAt': '2026-11-09T13:02:00.000Z'},
          ]),
          200,
        ),
      ),
    );

    final list = await client.getList('/attendance/me');

    expect(list, hasLength(1));
  });
}
