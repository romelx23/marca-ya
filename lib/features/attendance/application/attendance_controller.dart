import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../auth/application/auth_controller.dart';
import '../data/attendance_repository.dart';
import '../data/location_service.dart';

final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  return ApiAttendanceRepository(
    ref.watch(apiClientProvider),
    () => ref.read(authControllerProvider).valueOrNull?.token,
  );
});

final locationServiceProvider = Provider<LocationService>(
  (ref) => GeolocatorLocationService(),
);

final attendanceControllerProvider =
    AsyncNotifierProvider<AttendanceController, AttendanceDay>(
      AttendanceController.new,
    );

class AttendanceController extends AsyncNotifier<AttendanceDay> {
  @override
  Future<AttendanceDay> build() {
    // Al cambiar de usuario se descarta el estado del anterior y se vuelve a consultar.
    ref.watch(authControllerProvider.select((s) => s.valueOrNull?.employee.id));
    return _load();
  }

  Future<AttendanceDay> _load() async {
    try {
      return await ref.read(attendanceRepositoryProvider).today();
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        await ref.read(authControllerProvider.notifier).logout();
      }
      rethrow;
    }
  }

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }

  /// Marca la acción que toca según el servidor. Devuelve el error, o null si salió bien.
  Future<String?> mark() async {
    final current = state.valueOrNull;
    if (current == null) return null;
    final repo = ref.read(attendanceRepositoryProvider);
    try {
      final coords = await ref.read(locationServiceProvider).current();
      await repo.mark(current.checkedIn ? 'out' : 'in', coords: coords);
      state = AsyncData(await repo.today());
      return null;
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        await ref.read(authControllerProvider.notifier).logout();
      } else if (e.statusCode == 409) {
        // Otro dispositivo ya cambió el estado: se sincroniza con el servidor.
        state = await AsyncValue.guard(repo.today);
      }
      return e.message;
    }
  }
}
