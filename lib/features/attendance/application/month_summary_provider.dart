import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/work_day.dart';
import 'attendance_controller.dart';

/// Resumen del mes en curso para el inicio. Se vuelve a pedir al marcar.
final monthSummaryProvider = FutureProvider.autoDispose<MonthSummary>((
  ref,
) async {
  final now = DateTime.now();
  final from = DateTime(now.year, now.month, 1);
  final to = DateTime(now.year, now.month + 1, 0);
  final records = await ref
      .read(attendanceRepositoryProvider)
      .history(from: from, to: to);
  return MonthSummary(groupByDay(records));
});
