import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/application/auth_controller.dart';
import '../../notifications/application/push_registrar.dart';
import '../../face/application/face_providers.dart';
import '../../face/data/face_api.dart';
import '../../face/presentation/face_capture_page.dart';
import '../../face/presentation/face_enroll_page.dart';
import '../../notifications/data/push_service.dart';
import '../application/attendance_controller.dart';
import '../data/attendance_repository.dart';

const _workday = Duration(hours: 8);
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

String _dateLabel(DateTime d) {
  final w = _weekdays[d.weekday - 1];
  return '${w[0].toUpperCase()}${w.substring(1)}, ${d.day} de ${_months[d.month - 1]}';
}

String _clock(int seconds) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(seconds ~/ 3600)}:${two(seconds % 3600 ~/ 60)}:${two(seconds % 60)}';
}

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ring = AnimationController(
    vsync: this,
    duration: Motion.slow,
  );
  Timer? _tick;
  bool _busy = false;

  StreamSubscription<PushNotice>? _noticeSub;

  @override
  void initState() {
    super.initState();
    // Registra este dispositivo para recibir notificaciones y muestra las que llegan con la app abierta.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(ref.read(pushRegistrarProvider).register());
      _noticeSub = ref.read(pushServiceProvider).foreground.listen((n) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(n.body.isEmpty ? n.title : '${n.title}: ${n.body}'),
            ),
          );
      });
    });
  }

  @override
  void dispose() {
    _noticeSub?.cancel();
    _tick?.cancel();
    _ring.dispose();
    super.dispose();
  }

  /// El reloj solo corre mientras hay una entrada abierta.
  void _syncTicker(bool running) {
    if (running && _tick == null) {
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!running) {
      _tick?.cancel();
      _tick = null;
    }
  }

  /// Pide confirmación antes de una acción. Devuelve true si el usuario acepta.
  Future<bool> _confirm({
    required IconData icon,
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final p = context.palette;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: Theme.of(ctx).colorScheme.surface,
            border: Border.all(color: p.border),
            boxShadow: [
              BoxShadow(
                color: AppColors.indigo.withValues(alpha: .25),
                blurRadius: 40,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF8B84FF), Color(0xFF4EE3B5)],
                  ),
                ),
                child: Icon(icon, color: Colors.white),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: p.textMuted, height: 1.4),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: const Key('confirm-cancel'),
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: p.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      key: const Key('confirm-ok'),
                      onPressed: () => Navigator.pop(ctx, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.indigo,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(confirmLabel),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    return ok ?? false;
  }

  Future<void> _logout() async {
    final ok = await _confirm(
      icon: Icons.logout_rounded,
      title: '¿Cerrar sesión?',
      message: 'Tendrás que volver a ingresar con tu correo y clave.',
      confirmLabel: 'Cerrar sesión',
    );
    if (!ok) return;
    // Primero se quita el dispositivo del empleado (aún hay token de sesión) y luego se cierra la sesión.
    await ref.read(pushRegistrarProvider).unregister();
    await ref.read(authControllerProvider.notifier).logout();
  }

  Future<void> _mark() async {
    if (_busy) return;
    final day = ref.read(attendanceControllerProvider).valueOrNull;
    if (day == null) return;
    final out = day.checkedIn;
    final worked = _short(day.workedAt(DateTime.now()));
    final ok = await _confirm(
      icon: out ? Icons.logout_rounded : Icons.login_rounded,
      title: out ? '¿Marcar tu salida?' : '¿Marcar tu entrada?',
      message: out
          ? 'Llevas $worked trabajadas hoy. Se registrará con la hora del servidor y tu ubicación.'
          : 'Se registrará con la hora del servidor y tu ubicación actual.',
      confirmLabel: out ? 'Marcar salida' : 'Marcar entrada',
    );
    if (!ok || !mounted) return;
    // Si el empleado tiene rostro registrado, se captura y se marca con su embedding.
    final status = await _faceStatus();
    if (!mounted) return;
    List<double>? embedding;
    if (status != null && status.consented && status.templates > 0) {
      embedding = await Navigator.of(context).push<List<double>>(
        MaterialPageRoute(builder: (_) => const FaceCapturePage()),
      );
      if (embedding == null || !mounted) return;
    }
    await _runMark(embedding: embedding);
  }

  Future<FaceStatus?> _faceStatus() async {
    try {
      return await ref.read(faceApiProvider).status();
    } catch (_) {
      return null;
    }
  }

  Future<void> _markWithPin() async {
    if (_busy) return;
    final pin = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Marcar con PIN'),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 6,
            decoration: const InputDecoration(labelText: 'PIN'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('Marcar'),
            ),
          ],
        );
      },
    );
    if (pin == null || pin.isEmpty || !mounted) return;
    await _runMark(pin: pin);
  }

  Future<void> _runMark({List<double>? embedding, String? pin}) async {
    setState(() => _busy = true);
    final sweep = _ring.forward(from: 0);
    final error = await ref
        .read(attendanceControllerProvider.notifier)
        .mark(embedding: embedding, pin: pin);
    await sweep;
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final day = ref.watch(attendanceControllerProvider);
    _syncTicker(day.valueOrNull?.checkedIn ?? false);
    final employee = ref.watch(authControllerProvider).valueOrNull?.employee;
    final name = employee?.firstName ?? '';
    final fullName = employee?.fullName ?? '';
    final p = context.palette;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.2),
            radius: 1.1,
            colors: [p.glow, p.bg],
          ),
        ),
        child: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _dateLabel(DateTime.now()),
                      style: TextStyle(color: p.textMuted),
                    ).animate().fadeIn(duration: Motion.medium),
                    Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Hola, $name',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Mi rostro',
                              icon: Icon(
                                Icons.face_retouching_natural,
                                color: p.textMuted,
                              ),
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const FaceEnrollPage(),
                                ),
                              ),
                            ),
                            const ThemeToggleButton(),
                            _Avatar(fullName),
                            IconButton(
                              tooltip: 'Cerrar sesión',
                              icon: Icon(Icons.logout, color: p.textMuted),
                              onPressed: _logout,
                            ),
                          ],
                        )
                        .animate()
                        .fadeIn(duration: Motion.medium)
                        .slideY(begin: .2, curve: Motion.curve),
                    Expanded(
                      child: Center(
                        child: SingleChildScrollView(
                          child: day.when(
                            loading: () => const CircularProgressIndicator(),
                            error: (e, _) => _LoadError(
                              message: e is ApiException
                                  ? e.message
                                  : 'No se pudo cargar tu jornada',
                              onRetry: () => ref
                                  .read(attendanceControllerProvider.notifier)
                                  .reload(),
                            ),
                            data: _buildMarker,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMarker(AttendanceDay day) {
    final p = context.palette;
    final worked = day.workedAt(DateTime.now());
    final dayProgress = (worked / _workday.inSeconds).clamp(0.0, 1.0);
    final firstIn = day.firstIn;
    final remaining = _workday.inSeconds - worked;
    final clock = _clock(worked);
    final base = clock.substring(0, clock.length - 2); // "HH:MM:"
    final seconds = clock.substring(clock.length - 2);
    final colors = day.checkedIn
        ? const [Color(0xFF7CF5D2), Color(0xFF3FD9AB)]
        : const [Color(0xFF8B84FF), Color(0xFF5B52F0)];
    final glow = day.checkedIn ? AppColors.mint : AppColors.indigo;
    // Texto oscuro sobre el menta, blanco sobre el índigo.
    final onButton = day.checkedIn ? const Color(0xFF06231B) : Colors.white;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _busy ? null : _mark,
          child: AnimatedBuilder(
            animation: _ring,
            builder: (context, child) => CustomPaint(
              painter: _RingPainter(_busy ? _ring.value : dayProgress, p.track),
              child: Container(
                width: 260,
                height: 260,
                alignment: Alignment.center,
                child: AnimatedContainer(
                  duration: Motion.medium,
                  curve: Motion.curve,
                  width: 210,
                  height: 210,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: colors,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: glow.withValues(alpha: .35),
                        blurRadius: 40,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Container(
                    width: 190,
                    height: 190,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: .35),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: onButton.withValues(alpha: .16),
                          ),
                          child: Icon(
                            day.checkedIn
                                ? Icons.logout_rounded
                                : Icons.login_rounded,
                            size: 28,
                            color: onButton,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          day.checkedIn ? 'Marcar salida' : 'Marcar entrada',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: onButton,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          day.checkedIn
                              ? 'Termina tu jornada'
                              : 'Empieza tu jornada',
                          style: TextStyle(
                            fontSize: 12,
                            color: onButton.withValues(alpha: .75),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ).animate().scale(duration: Motion.slow, curve: Curves.elasticOut),
        const SizedBox(height: 28),
        Text(
          'HORAS TRABAJADAS HOY',
          style: TextStyle(
            fontSize: 12,
            letterSpacing: 1.5,
            color: p.textMuted,
          ),
        ),
        const SizedBox(height: 6),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: base),
              TextSpan(
                text: seconds,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
            ],
          ),
          key: const Key('worked-clock'),
          style: const TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.w800,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          remaining > 0
              ? 'Faltan ${_short(remaining)} de ${_workday.inHours}h'
              : 'Jornada completa',
          style: TextStyle(color: p.textMuted),
        ),
        const SizedBox(height: 8),
        TextButton(
          key: const Key('mark-with-pin'),
          onPressed: _busy ? null : _markWithPin,
          child: const Text('Marcar con PIN'),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _StatCard('Entrada', firstIn == null ? '—' : _hm(firstIn)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                'Salida est.',
                firstIn == null ? '—' : _hm(firstIn.add(_workday)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                'Estado',
                day.checkedIn
                    ? 'En turno'
                    : (worked > 0 ? 'Salió' : 'Sin marcar'),
                valueColor: day.checkedIn
                    ? Theme.of(context).colorScheme.secondary
                    : null,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

String _hm(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

String _short(int seconds) =>
    '${seconds ~/ 3600}h ${(seconds % 3600 ~/ 60).toString().padLeft(2, '0')}m';

class _StatCard extends StatelessWidget {
  const _StatCard(this.label, this.value, {this.valueColor});
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: p.textMuted)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar(this.name);
  final String name;

  @override
  Widget build(BuildContext context) {
    final initials = name.trim().isEmpty
        ? '?'
        : name.trim().split(RegExp(r'\s+')).take(2).map((w) => w[0]).join();
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF8B84FF), Color(0xFF4EE3B5)],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: .15),
          width: 2,
        ),
      ),
      child: Text(
        initials.toUpperCase(),
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFFFF6B6B)),
        ),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: onRetry, child: const Text('Reintentar')),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.t, this.trackColor);
  final double t;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..color = trackColor;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..shader = const SweepGradient(
        startAngle: 0,
        endAngle: math.pi * 2,
        colors: [Color(0xFF6C63FF), Color(0xFF5AA9F0), Color(0xFF4EE3B5)],
        transform: GradientRotation(-math.pi / 2),
      ).createShader(rect);
    final r = rect.deflate(7);
    canvas.drawArc(r, 0, math.pi * 2, false, track);
    if (t > 0) {
      canvas.drawArc(r, -math.pi / 2, math.pi * 2 * t, false, arc);
      // Perilla luminosa al final del progreso.
      final a = -math.pi / 2 + math.pi * 2 * t;
      final knob = r.center + Offset(math.cos(a), math.sin(a)) * r.width / 2;
      canvas.drawCircle(
        knob,
        13,
        Paint()
          ..color = AppColors.mint.withValues(alpha: .35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      canvas.drawCircle(knob, 8, Paint()..color = const Color(0xFFE8FFF7));
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.t != t || old.trackColor != trackColor;
}
