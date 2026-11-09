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

/// Una marcación del historial, con la hora ya en la zona local del dispositivo.
class AttendanceRecord {
  const AttendanceRecord({required this.type, required this.occurredAt});

  factory AttendanceRecord.fromJson(Map<String, dynamic> j) => AttendanceRecord(
    type: j['type'] as String,
    occurredAt: DateTime.parse(j['occurredAt'] as String).toLocal(),
  );

  /// 'in' o 'out'.
  final String type;
  final DateTime occurredAt;
}

abstract class AttendanceRepository {
  Future<AttendanceDay> today();

  /// Marcaciones entre [from] y [to], ambos incluidos (días locales).
  Future<List<AttendanceRecord>> history({
    required DateTime from,
    required DateTime to,
  });

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
  Future<List<AttendanceRecord>> history({
    required DateTime from,
    required DateTime to,
  }) async {
    final res = await _api.getList(
      '/attendance/me?from=${_ymd(from)}&to=${_ymd(to)}',
      token: _token(),
    );
    return res
        .cast<Map<String, dynamic>>()
        .map(AttendanceRecord.fromJson)
        .toList();
  }

  static String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  @override
  Future<void> mark(String type, {Coords? coords}) async {
    await _api.post('/attendance', {
      'type': type,
      if (coords != null) 'latitude': coords.latitude,
      if (coords != null) 'longitude': coords.longitude,
    }, token: _token());
  }
}
