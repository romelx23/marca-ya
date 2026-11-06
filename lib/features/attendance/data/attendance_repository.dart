import '../../../core/api/api_client.dart';
import 'location_service.dart';

/// Estado del día según el servidor.
class AttendanceDay {
  const AttendanceDay({
    required this.checkedIn,
    required this.workedSeconds,
    required this.fetchedAt,
    this.firstIn,
  });

  factory AttendanceDay.fromJson(Map<String, dynamic> j, DateTime fetchedAt) {
    final events = (j['events'] as List).cast<Map<String, dynamic>>();
    final firstIn = events
        .where((e) => e['type'] == 'in')
        .map((e) => DateTime.parse(e['occurredAt'] as String))
        .firstOrNull;
    return AttendanceDay(
      checkedIn: j['checkedIn'] as bool,
      workedSeconds: (j['workedSeconds'] as num).toInt(),
      fetchedAt: fetchedAt,
      firstIn: firstIn?.toLocal(),
    );
  }

  final bool checkedIn;

  /// Segundos trabajados al momento de [fetchedAt].
  final int workedSeconds;
  final DateTime fetchedAt;
  final DateTime? firstIn;

  /// Segundos trabajados ahora: si hay entrada abierta, sigue contando desde la consulta.
  int workedAt(DateTime now) {
    if (!checkedIn) return workedSeconds;
    final extra = now.difference(fetchedAt).inSeconds;
    return workedSeconds + (extra < 0 ? 0 : extra);
  }
}

abstract class AttendanceRepository {
  Future<AttendanceDay> today();

  /// [type] es 'in' o 'out'. Lanza [ApiException] (409 si la secuencia no corresponde).
  Future<void> mark(String type, {Coords? coords});
}

class ApiAttendanceRepository implements AttendanceRepository {
  ApiAttendanceRepository(this._api, this._token);

  final ApiClient _api;
  final String? Function() _token;

  @override
  Future<AttendanceDay> today() async {
    final res = await _api.get('/attendance/today', token: _token());
    return AttendanceDay.fromJson(res, DateTime.now());
  }

  @override
  Future<void> mark(String type, {Coords? coords}) async {
    await _api.post('/attendance', {
      'type': type,
      if (coords != null) 'latitude': coords.latitude,
      if (coords != null) 'longitude': coords.longitude,
    }, token: _token());
  }
}
