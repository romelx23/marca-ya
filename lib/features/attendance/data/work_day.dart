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

  /// Igual que [workedSeconds], pero una entrada abierta cuenta hasta [now].
  int workedSecondsAt(DateTime now) {
    var total = workedSeconds;
    if (open) {
      final extra = now.difference(records.last.occurredAt).inSeconds;
      if (extra > 0) total += extra;
    }
    return total;
  }

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

/// Totales de un mes: horas trabajadas y días con al menos una entrada.
class MonthSummary {
  MonthSummary(this.days);

  final List<WorkDay> days;

  int get workedSeconds => days.fold(0, (s, d) => s + d.workedSeconds);

  int workedSecondsAt(DateTime now) =>
      days.fold(0, (s, d) => s + d.workedSecondsAt(now));

  int get daysWorked => days.where((d) => d.firstIn != null).length;
}

/// Celdas de un mes en cuadrícula de 7 columnas, lunes primero.
/// Las celdas nulas son huecos antes del día 1.
List<DateTime?> monthCells(DateTime month) {
  final count = DateTime(month.year, month.month + 1, 0).day;
  final lead = DateTime(month.year, month.month, 1).weekday - 1;
  return [
    for (var i = 0; i < lead; i++) null,
    for (var d = 1; d <= count; d++) DateTime(month.year, month.month, d),
  ];
}
