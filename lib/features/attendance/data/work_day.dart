import 'attendance_repository.dart';

/// Las marcaciones de un mismo día local, en orden cronológico.
class WorkDay {
  WorkDay(this.day, this.records);

  /// Medianoche local del día.
  final DateTime day;
  final List<AttendanceRecord> records;

  DateTime? get firstIn =>
      records.where((r) => r.type == 'in').map((r) => r.occurredAt).firstOrNull;

  DateTime? get lastOut =>
      records.where((r) => r.type == 'out').map((r) => r.occurredAt).lastOrNull;

  /// Hay una entrada sin salida: la jornada sigue abierta.
  bool get open => records.isNotEmpty && records.last.type == 'in';

  /// Suma cada par entrada → salida. Una entrada sin salida no suma.
  int get workedSeconds {
    var total = 0;
    DateTime? start;
    for (final r in records) {
      if (r.type == 'in') {
        start ??= r.occurredAt;
      } else if (start != null) {
        total += r.occurredAt.difference(start).inSeconds;
        start = null;
      }
    }
    return total < 0 ? 0 : total;
  }
}

/// Agrupa marcaciones por día local, del más reciente al más antiguo.
List<WorkDay> groupByDay(List<AttendanceRecord> records) {
  final byDay = <DateTime, List<AttendanceRecord>>{};
  for (final r in records) {
    final d = r.occurredAt;
    byDay.putIfAbsent(DateTime(d.year, d.month, d.day), () => []).add(r);
  }
  final days = [
    for (final entry in byDay.entries)
      WorkDay(
        entry.key,
        [...entry.value]..sort((a, b) => a.occurredAt.compareTo(b.occurredAt)),
      ),
  ]..sort((a, b) => b.day.compareTo(a.day));
  return days;
}
