import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../application/attendance_controller.dart';
import '../data/work_day.dart';
import 'format.dart';

const _weekdayLetters = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

/// Historial del empleado por mes: resumen, calendario y detalle del día elegido.
class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  late DateTime _month;
  late DateTime _selected;
  late Future<List<WorkDay>> _days;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _selected = DateTime(now.year, now.month, now.day);
    _days = _load(_month);
  }

  Future<List<WorkDay>> _load(DateTime month) {
    final from = DateTime(month.year, month.month, 1);
    final to = DateTime(month.year, month.month + 1, 0);
    return ref
        .read(attendanceRepositoryProvider)
        .history(from: from, to: to)
        .then(groupByDay);
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _month.year == now.year && _month.month == now.month;
  }

  void _changeMonth(int delta) {
    final month = DateTime(_month.year, _month.month + delta);
    final now = DateTime.now();
    setState(() {
      _month = month;
      // Al cambiar de mes, se selecciona hoy si está en ese mes, o el día 1.
      _selected = month.year == now.year && month.month == now.month
          ? DateTime(now.year, now.month, now.day)
          : DateTime(month.year, month.month, 1);
      _days = _load(month);
    });
  }

  void _retry() => setState(() => _days = _load(_month));

  @override
  Widget build(BuildContext context) {
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
          return _MonthView(
            month: _month,
            selected: _selected,
            days: snap.data ?? const [],
            isCurrentMonth: _isCurrentMonth,
            onPrevious: () => _changeMonth(-1),
            onNext: () => _changeMonth(1),
            onSelect: (d) => setState(() => _selected = d),
          );
        },
      ),
    );
  }
}

class _MonthView extends StatelessWidget {
  const _MonthView({
    required this.month,
    required this.selected,
    required this.days,
    required this.isCurrentMonth,
    required this.onPrevious,
    required this.onNext,
    required this.onSelect,
  });

  final DateTime month;
  final DateTime selected;
  final List<WorkDay> days;
  final bool isCurrentMonth;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final byDay = {for (final d in days) d.day.day: d};
    final summary = MonthSummary(days);
    final cells = monthCells(month);
    final selectedDay = byDay[selected.day];
    final p = context.palette;

    // Column (no ListView): el detalle del día debe existir aunque esté bajo la vista.
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MonthHeader(
            label: monthLabel(month),
            onPrevious: onPrevious,
            onNext: isCurrentMonth ? null : onNext,
          ),
          const SizedBox(height: 12),
          _SummaryCard(summary: summary),
          const SizedBox(height: 16),
          Row(
            children: [
              for (final l in _weekdayLetters)
                Expanded(
                  child: Center(
                    child: Text(
                      l,
                      style: TextStyle(color: p.textMuted, fontSize: 12),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (final d in cells)
                d == null
                    ? const SizedBox.shrink()
                    : _DayCell(
                        day: d,
                        hasRecords: byDay.containsKey(d.day),
                        selected: d.day == selected.day,
                        onTap: () => onSelect(d),
                      ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            dayLabel(selected),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          if (selectedDay == null)
            Text(
              'Sin marcaciones este día',
              style: TextStyle(color: p.textMuted),
            )
          else
            _DayTile(selectedDay),
        ],
      ),
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.label,
    required this.onPrevious,
    required this.onNext,
  });

  final String label;
  final VoidCallback onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          tooltip: 'Mes anterior',
          icon: const Icon(Icons.chevron_left),
          onPressed: onPrevious,
        ),
        Expanded(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
        ),
        IconButton(
          tooltip: 'Mes siguiente',
          icon: const Icon(Icons.chevron_right),
          onPressed: onNext,
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});
  final MonthSummary summary;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: AppColors.indigoGradient,
        boxShadow: [
          BoxShadow(
            color: AppColors.indigo.withValues(alpha: .3),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _SummaryStat(
              label: 'Horas del mes',
              value: duration(summary.workedSecondsAt(DateTime.now())),
            ),
          ),
          Container(width: 1, height: 40, color: p.border),
          Expanded(
            child: _SummaryStat(
              label: 'Días con entrada',
              value: '${summary.daysWorked}',
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.hasRecords,
    required this.selected,
    required this.onTap,
  });

  final DateTime day;
  final bool hasRecords;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isToday =
        day.year == now.year && day.month == now.month && day.day == now.day;
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: selected ? AppColors.indigoGradient : null,
          border: isToday && !selected
              ? Border.all(color: AppColors.indigo, width: 1.5)
              : null,
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${day.day}',
              style: TextStyle(
                fontWeight: selected || isToday
                    ? FontWeight.w800
                    : FontWeight.w500,
                color: selected ? Colors.white : null,
              ),
            ),
            if (hasRecords)
              Container(
                width: 5,
                height: 5,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? Colors.white : scheme.secondary,
                ),
              ),
          ],
        ),
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
            child: Text(
              'Entrada ${firstIn == null ? '—' : hm(firstIn)}'
              '  ·  Salida ${lastOut == null ? '—' : hm(lastOut)}',
              style: TextStyle(color: p.textMuted, fontSize: 13),
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
