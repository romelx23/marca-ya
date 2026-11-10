import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marca_ya/features/attendance/application/attendance_controller.dart';
import 'package:marca_ya/features/attendance/data/attendance_repository.dart';
import 'package:marca_ya/features/attendance/data/location_service.dart';
import 'package:marca_ya/features/auth/application/auth_controller.dart';
import 'package:marca_ya/features/face/application/face_providers.dart';
import 'package:marca_ya/features/face/data/face_api.dart';
import 'package:marca_ya/core/api/api_client.dart';
import 'package:marca_ya/features/notifications/application/push_registrar.dart';
import 'package:marca_ya/features/notifications/data/push_service.dart';
import 'package:marca_ya/features/auth/data/auth_repository.dart';
import 'package:marca_ya/main.dart';

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.saved});
  Session? saved;

  static const _ana = Employee(
    id: '1',
    email: 'ana@test.local',
    fullName: 'Ana Ruiz',
    role: 'employee',
  );

  @override
  Future<Session> login(String email, String password) async {
    if (password != 'correcta') {
      throw ApiException(401, 'Credenciales inválidas');
    }
    return saved = Session(token: 't', employee: _ana);
  }

  @override
  Future<Session?> restore() async => saved;

  @override
  Future<void> logout() async => saved = null;
}

/// Sin rostro registrado: la app marca como antes, sin llamar al servidor.
class FakeFaceApi extends FaceApi {
  FakeFaceApi() : super(ApiClient(baseUrl: 'http://localhost:0'), () => null);

  @override
  Future<FaceStatus> status() async => const FaceStatus(
    currentConsentVersion: '2026-11-v1',
    consented: false,
    templates: 0,
    pinSet: false,
  );
}

class FakeAttendanceRepository implements AttendanceRepository {
  bool checkedIn = false;
  int worked = 0;
  Object? loadError;
  ApiException? markError;

  @override
  Future<AttendanceDay> today() async {
    if (loadError != null) throw loadError!;
    return AttendanceDay(
      checkedIn: checkedIn,
      workedSeconds: worked,
      fetchedAt: DateTime.now(),
    );
  }

  Coords? lastCoords;

  String? lastPin;
  List<double>? lastEmbedding;

  @override
  Future<void> mark(
    String type, {
    Coords? coords,
    List<double>? embedding,
    String? pin,
  }) async {
    lastCoords = coords;
    lastPin = pin;
    lastEmbedding = embedding;
    if (markError != null) throw markError!;
    checkedIn = type == 'in';
  }
}

class FakeLocationService implements LocationService {
  FakeLocationService([this.coords]);
  Coords? coords;

  @override
  Future<Coords?> current() async => coords;
}

Future<void> pumpApp(
  WidgetTester tester,
  FakeAuthRepository auth, [
  FakeAttendanceRepository? attendance,
  FakeLocationService? location,
]) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        pushServiceProvider.overrideWithValue(NoPushService()),
        faceApiProvider.overrideWithValue(FakeFaceApi()),
        locationServiceProvider.overrideWithValue(
          location ?? FakeLocationService(),
        ),
        authRepositoryProvider.overrideWithValue(auth),
        attendanceRepositoryProvider.overrideWithValue(
          attendance ?? FakeAttendanceRepository(),
        ),
      ],
      child: const MarcaYaApp(),
    ),
  );
  await tester.pumpAndSettle();
}

/// Con una entrada abierta el reloj corre cada segundo y pumpAndSettle no termina.
Future<void> pumpFor(
  WidgetTester tester, [
  Duration d = const Duration(milliseconds: 1500),
]) async {
  await tester.pump();
  await tester.pump(d);
}

/// Responde al diálogo de confirmación (acepta o cancela).
Future<void> answerDialog(WidgetTester tester, {bool accept = true}) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.tap(find.byKey(Key(accept ? 'confirm-ok' : 'confirm-cancel')));
}

/// Desmonta la app para cancelar el reloj antes de que termine el test.
Future<void> unmount(WidgetTester tester) =>
    tester.pumpWidget(const SizedBox());

Future<FakeAuthRepository> loggedIn() async {
  final repo = FakeAuthRepository();
  await repo.login('ana@test.local', 'correcta');
  return repo;
}

void main() {
  testWidgets('sin sesión muestra el login y rechaza una clave incorrecta', (
    tester,
  ) async {
    await pumpApp(tester, FakeAuthRepository());
    expect(find.text('Ingresar'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('email')), 'ana@test.local');
    await tester.enterText(find.byKey(const Key('password')), 'mala');
    await tester.tap(find.byKey(const Key('login-button')));
    await tester.pumpAndSettle();

    expect(find.text('Credenciales inválidas'), findsOneWidget);
    expect(find.text('Marcar entrada'), findsNothing);
  });

  testWidgets('el botón de tema alterna entre oscuro y claro', (tester) async {
    await pumpApp(tester, FakeAuthRepository());
    Brightness brightness() =>
        Theme.of(tester.element(find.text('MarcaYa'))).brightness;
    final before = brightness();

    await tester.tap(find.byTooltip('Cambiar tema'));
    await tester.pumpAndSettle();
    expect(brightness(), isNot(before));

    await tester.tap(find.byTooltip('Cambiar tema'));
    await tester.pumpAndSettle();
    expect(brightness(), before);
  });

  testWidgets('login correcto entra al Home y cerrar sesión vuelve al login', (
    tester,
  ) async {
    await pumpApp(tester, FakeAuthRepository());
    await tester.enterText(find.byKey(const Key('email')), 'ana@test.local');
    await tester.enterText(find.byKey(const Key('password')), 'correcta');
    await tester.tap(find.byKey(const Key('login-button')));
    await tester.pumpAndSettle();

    expect(find.text('Hola, Ana'), findsOneWidget);
    expect(find.text('Marcar entrada'), findsOneWidget);

    await tester.tap(find.byTooltip('Cerrar sesión'));
    await tester.pumpAndSettle();
    expect(find.text('¿Cerrar sesión?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirm-ok')));
    await tester.pumpAndSettle();
    expect(find.text('Ingresar'), findsOneWidget);
  });

  testWidgets('el Home refleja la jornada del servidor', (tester) async {
    final server = FakeAttendanceRepository()
      ..checkedIn = true
      ..worked = 3725; // 01:02:05
    await pumpApp(tester, await loggedIn(), server);
    await tester.pump(const Duration(milliseconds: 1500));

    expect(find.text('Marcar salida'), findsOneWidget);
    expect(find.byKey(const Key('worked-clock')), findsOneWidget);
    final clock = tester
        .widget<Text>(find.byKey(const Key('worked-clock')))
        .textSpan!
        .toPlainText();
    expect(clock.startsWith('01:02:'), isTrue, reason: clock);
    await unmount(tester);
  });

  testWidgets('tocar el botón marca entrada y luego salida', (tester) async {
    final server = FakeAttendanceRepository();
    await pumpApp(tester, await loggedIn(), server);
    expect(find.text('Marcar entrada'), findsOneWidget);

    await tester.tap(find.text('Marcar entrada'));
    await answerDialog(tester);
    await pumpFor(tester);
    expect(server.checkedIn, isTrue);
    expect(find.text('Marcar salida'), findsOneWidget);

    await tester.tap(find.text('Marcar salida'));
    await answerDialog(tester);
    await pumpFor(tester);
    expect(server.checkedIn, isFalse);
    expect(find.text('Marcar entrada'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets(
    'la marcación envía la ubicación y muestra el rechazo de la geocerca',
    (tester) async {
      final server = FakeAttendanceRepository();
      await pumpApp(
        tester,
        await loggedIn(),
        server,
        FakeLocationService(const Coords(-12.04, -77.03)),
      );

      await tester.tap(find.text('Marcar entrada'));
      await answerDialog(tester);
      await pumpFor(tester);
      expect(server.lastCoords?.latitude, -12.04);
      expect(server.lastCoords?.longitude, -77.03);
      expect(find.text('Marcar salida'), findsOneWidget);

      server.markError = ApiException(
        403,
        'Estás a 900 m de la oficina; acércate para marcar',
      );
      await tester.tap(find.text('Marcar salida'));
      await answerDialog(tester);
      await pumpFor(tester);
      expect(
        find.text('Estás a 900 m de la oficina; acércate para marcar'),
        findsOneWidget,
      );
      expect(find.text('Marcar salida'), findsOneWidget);
      await unmount(tester);
    },
  );

  testWidgets('cancelar la confirmación no marca nada', (tester) async {
    final server = FakeAttendanceRepository();
    await pumpApp(
      tester,
      await loggedIn(),
      server,
      FakeLocationService(const Coords(1, 2)),
    );

    await tester.tap(find.text('Marcar entrada'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('¿Marcar tu entrada?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirm-cancel')));
    await tester.pumpAndSettle();

    expect(server.checkedIn, isFalse);
    expect(server.lastCoords, isNull);
    expect(find.text('Marcar entrada'), findsOneWidget);
  });

  testWidgets('marcar con PIN envía el PIN y no un rostro', (tester) async {
    final server = FakeAttendanceRepository();
    await pumpApp(tester, await loggedIn(), server);

    await tester.tap(find.byKey(const Key('mark-with-pin')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '1234');
    await tester.tap(find.text('Marcar'));
    await pumpFor(tester);

    expect(server.lastPin, '1234');
    expect(server.lastEmbedding, isNull);
    expect(server.checkedIn, isTrue);
    await unmount(tester);
  });

  testWidgets('un 409 muestra el mensaje y se sincroniza con el servidor', (
    tester,
  ) async {
    final server = FakeAttendanceRepository();
    await pumpApp(tester, await loggedIn(), server);
    expect(find.text('Marcar entrada'), findsOneWidget);

    // Otro dispositivo ya marcó entrada mientras tanto.
    server
      ..checkedIn = true
      ..markError = ApiException(409, 'Ya marcaste entrada: marca salida');
    await tester.tap(find.text('Marcar entrada'));
    await answerDialog(tester);
    await pumpFor(tester);

    expect(find.text('Ya marcaste entrada: marca salida'), findsOneWidget);
    expect(find.text('Marcar salida'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('si falla la carga ofrece reintentar', (tester) async {
    final server = FakeAttendanceRepository()
      ..loadError = ApiException(0, 'No se pudo conectar con el servidor');
    await pumpApp(tester, await loggedIn(), server);
    expect(find.text('No se pudo conectar con el servidor'), findsOneWidget);

    server.loadError = null;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('Marcar entrada'), findsOneWidget);
  });
}
