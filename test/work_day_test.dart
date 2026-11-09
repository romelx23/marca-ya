import 'package:flutter_test/flutter_test.dart';
import 'package:marca_ya/features/attendance/data/attendance_repository.dart';
import 'package:marca_ya/features/attendance/data/work_day.dart';

AttendanceRecord marca(String type, int hour, int minute, {int day = 9}) =>
    AttendanceRecord(
      type: type,
      occurredAt: DateTime(2026, 11, day, hour, minute),
    );

void main() {
  test('suma cada par entrada → salida', () {
    final dia = WorkDay(DateTime(2026, 11, 9), [
      marca('in', 8, 0),
      marca('out', 12, 0),
      marca('in', 13, 0),
      marca('out', 17, 30),
    ]);

    expect(dia.workedSeconds, 8 * 3600 + 30 * 60);
    expect(dia.firstIn, DateTime(2026, 11, 9, 8, 0));
    expect(dia.lastOut, DateTime(2026, 11, 9, 17, 30));
    expect(dia.open, isFalse);
  });

  test('una entrada sin salida no suma y deja la jornada abierta', () {
    final dia = WorkDay(DateTime(2026, 11, 9), [marca('in', 8, 0)]);

    expect(dia.workedSeconds, 0);
    expect(dia.lastOut, isNull);
    expect(dia.open, isTrue);
  });

  test('agrupa por día, del más reciente al más antiguo', () {
    final dias = groupByDay([
      marca('in', 8, 0, day: 8),
      marca('out', 9, 0, day: 8),
      marca('in', 8, 0, day: 9),
    ]);

    expect(dias.map((d) => d.day.day), [9, 8]);
    expect(dias.last.records.map((r) => r.type), ['in', 'out']);
  });

  test('ordena las marcaciones dentro del día aunque lleguen desordenadas', () {
    final dias = groupByDay([marca('out', 12, 0), marca('in', 8, 0)]);

    expect(dias.single.records.first.type, 'in');
    expect(dias.single.workedSeconds, 4 * 3600);
  });

  test('el resumen del mes suma horas y cuenta días con entrada', () {
    final dias = groupByDay([
      marca('in', 8, 0, day: 2),
      marca('out', 12, 0, day: 2),
      marca('in', 8, 0, day: 3),
      marca('out', 10, 0, day: 3),
    ]);
    final resumen = MonthSummary(dias);

    expect(resumen.workedSeconds, (4 + 2) * 3600);
    expect(resumen.daysWorked, 2);
  });

  test('la cuadrícula del mes empieza en lunes con huecos previos', () {
    // 1 de noviembre de 2026 es domingo: seis huecos antes del día 1.
    final celdas = monthCells(DateTime(2026, 11));

    expect(celdas.take(6), everyElement(isNull));
    expect(celdas[6], DateTime(2026, 11, 1));
    expect(celdas.whereType<DateTime>(), hasLength(30));
  });

  test('una jornada abierta cuenta hasta la hora indicada', () {
    final dia = WorkDay(DateTime(2026, 11, 9), [marca('in', 8, 0)]);

    expect(dia.workedSecondsAt(DateTime(2026, 11, 9, 10, 0)), 2 * 3600);
    expect(dia.workedSeconds, 0);
  });
}
