import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../application/attendance_controller.dart';
import '../data/work_day.dart';
import 'format.dart';

/// Días que muestra el historial, incluido hoy.
const historyDays = 30;

/// Historial de asistencias del empleado: una fila por día con marcaciones.
class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  late Future<List<WorkDay>> _days;

  @override
  void initState() {
    super.initState();
    _days = _load();
  }

  Future<List<WorkDay>> _load() {
    final today = DateTime.now();
    final to = DateTime(today.year, today.month, today.day);
    final from = to.subtract(const Duration(days: historyDays - 1));
    return ref
        .read(attendanceRepositoryProvider)
        .history(from: from, to: to)
        .then(groupByDay);
  }

  void _retry() => setState(() => _days = _load());

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      appBar: AppBar(title: const Text('Mi historial')),
      body: FutureBuilder<List<WorkDay>>(
        future: _days,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            final e = snap.error;
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      e is ApiException
                          ? e.message
                          : 'No se pudo cargar tu historial',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.error),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _retry,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            );
          }
          final days = snap.data ?? const <WorkDay>[];
          if (days.isEmpty) {
            return Center(
              child: Text(
                'Sin marcaciones en los últimos $historyDays días',
                style: TextStyle(color: p.textMuted),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: days.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _DayTile(days[i]),
          );
        },
      ),
    );
  }
}

class _DayTile extends StatelessWidget {
  const _DayTile(this.day);
  final WorkDay day;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final firstIn = day.firstIn;
    final lastOut = day.lastOut;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [p.cardTop, p.cardBottom],
        ),
        border: Border.all(color: p.border),
        boxShadow: p.cardShadow,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dayLabel(day.day),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Entrada ${firstIn == null ? '—' : hm(firstIn)}'
                  '  ·  Salida ${lastOut == null ? '—' : hm(lastOut)}',
                  style: TextStyle(color: p.textMuted, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                duration(day.workedSeconds),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              if (day.open)
                Text(
                  'En turno',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
