const _weekdays = [
  'lunes',
  'martes',
  'miércoles',
  'jueves',
  'viernes',
  'sábado',
  'domingo',
];
const _months = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

/// "Lunes, 9 de noviembre".
String dayLabel(DateTime d) {
  final w = _weekdays[d.weekday - 1];
  return '${w[0].toUpperCase()}${w.substring(1)}, ${d.day} de ${_months[d.month - 1]}';
}

/// "08:02".
String hm(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// "4h 05m".
String duration(int seconds) =>
    '${seconds ~/ 3600}h ${(seconds % 3600 ~/ 60).toString().padLeft(2, '0')}m';

/// "Noviembre 2026".
String monthLabel(DateTime d) {
  final m = _months[d.month - 1];
  return '${m[0].toUpperCase()}${m.substring(1)} ${d.year}';
}
