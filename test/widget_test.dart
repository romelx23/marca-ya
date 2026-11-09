import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marca_ya/core/api/api_client.dart';
import 'package:marca_ya/features/attendance/application/attendance_controller.dart';
import 'package:marca_ya/features/attendance/data/attendance_repository.dart';
import 'package:marca_ya/features/attendance/data/location_service.dart';
import 'package:marca_ya/features/attendance/presentation/format.dart';
import 'package:marca_ya/features/auth/application/auth_controller.dart';
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

  /// Marcaciones que devuelve el historial.
  List<AttendanceRecord> records = [];

  @override
  Future<List<AttendanceRecord>> history({
    required DateTime from,
    required DateTime to,
  }) async => records;

  @override
  Future<void> mark(String type, {Coords? coords}) async {
    lastCoords = coords;
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
  // Avanza en pasos: las continuaciones con `await` (p. ej. la animación del anillo) necesitan frames propios.
  for (var t = Duration.zero; t < d; t += const Duration(milliseconds: 100)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
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

/// Simula un fallo no previsto (no es un ApiException), como el del almacenamiento seguro.
class BrokenAuthRepository extends FakeAuthRepository {
  @override
  Future<Session> login(String email, String password) async {
    throw StateError('almacenamiento no disponible');
  }
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

    await tester.tap(find.byTooltip('Cuenta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cerrar sesión'));
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

  testWidgets('un error no previsto al iniciar sesión muestra mensaje', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(BrokenAuthRepository()),
        ],
        child: const MarcaYaApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('email')), 'ana@test.local');
    await tester.enterText(find.byKey(const Key('password')), 'correcta');
    await tester.tap(find.byKey(const Key('login-button')));
    await tester.pumpAndSettle();

    expect(
      find.text('No se pudo iniciar sesión. Intenta de nuevo.'),
      findsOneWidget,
    );
    expect(find.text('Ingresar'), findsOneWidget);
  });

  testWidgets('el historial muestra las horas y el total de cada día', (
    tester,
  ) async {
    final hoy = DateTime.now();
    final server = FakeAttendanceRepository()
      ..records = [
        AttendanceRecord(
          type: 'in',
          occurredAt: DateTime(hoy.year, hoy.month, hoy.day, 8, 2),
        ),
        AttendanceRecord(
          type: 'out',
          occurredAt: DateTime(hoy.year, hoy.month, hoy.day, 12, 0),
        ),
        AttendanceRecord(
          type: 'in',
          occurredAt: DateTime(hoy.year, hoy.month, hoy.day, 13, 0),
        ),
        AttendanceRecord(
          type: 'out',
          occurredAt: DateTime(hoy.year, hoy.month, hoy.day, 17, 30),
        ),
      ];
    await pumpApp(tester, await loggedIn(), server);

    await tester.tap(find.byTooltip('Cuenta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mi historial'));
    await tester.pumpAndSettle();

    expect(find.text(dayLabel(hoy)), findsOneWidget);
    expect(find.text('Entrada 08:02  ·  Salida 17:30'), findsOneWidget);
    expect(find.text('8h 28m'), findsOneWidget);
  });

  testWidgets('el historial sin marcaciones lo dice', (tester) async {
    await pumpApp(tester, await loggedIn(), FakeAttendanceRepository());

    await tester.tap(find.byTooltip('Cuenta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mi historial'));
    await tester.pumpAndSettle();

    expect(find.text('Sin marcaciones en los últimos 30 días'), findsOneWidget);
  });

  testWidgets('el perfil muestra los datos del empleado', (tester) async {
    await pumpApp(tester, await loggedIn(), FakeAttendanceRepository());

    await tester.tap(find.byTooltip('Cuenta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mi perfil'));
    await tester.pumpAndSettle();

    expect(find.text('Ana Ruiz'), findsWidgets);
    expect(find.text('ana@test.local'), findsOneWidget);
    expect(find.text('Sin documento registrado'), findsOneWidget);
    expect(find.text('Empleado'), findsWidgets);
  });

  testWidgets('el botón de marcar se anuncia como botón con su acción', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpApp(tester, await loggedIn(), FakeAttendanceRepository());

    expect(
      tester.getSemantics(find.bySemanticsLabel('Marcar entrada')),
      matchesSemantics(
        label: 'Marcar entrada',
        isButton: true,
        hasTapAction: true,
        hasEnabledState: true,
        isEnabled: true,
      ),
    );
    semantics.dispose();
  });

  testWidgets('marcar con éxito confirma la hora en un aviso', (tester) async {
    final server = FakeAttendanceRepository();
    await pumpApp(tester, await loggedIn(), server);

    await tester.tap(find.text('Marcar entrada'));
    await answerDialog(tester);
    await pumpFor(tester);

    expect(find.textContaining('Entrada registrada a las'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('no desborda en un teléfono angosto con texto ampliado', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final server = FakeAttendanceRepository()
      ..checkedIn = true
      ..worked = 30725; // 08:32:05
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(await loggedIn()),
          attendanceRepositoryProvider.overrideWithValue(server),
        ],
        child: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 640),
            textScaler: TextScaler.linear(2),
          ),
          child: const MarcaYaApp(),
        ),
      ),
    );
    await pumpFor(tester);

    expect(tester.takeException(), isNull);
    await unmount(tester);
    // Drena los temporizadores de animación que quedan al desmontar.
    await tester.pump(const Duration(milliseconds: 500));
  });
}
