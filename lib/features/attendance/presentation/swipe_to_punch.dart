import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';

/// Control de deslizar para marcar la salida. Hay que arrastrar la perilla hasta el final.
class SwipeToPunchOut extends StatefulWidget {
  const SwipeToPunchOut({super.key, required this.onComplete});

  /// Se llama al llegar al final. La confirmación la pide quien la usa.
  final VoidCallback onComplete;

  @override
  State<SwipeToPunchOut> createState() => _SwipeToPunchOutState();
}

class _SwipeToPunchOutState extends State<SwipeToPunchOut> {
  static const _height = 60.0;
  static const _thumb = 52.0;
  static const _pad = 4.0;

  /// Desplazamiento de la perilla dentro de la pista.
  double _dx = 0;

  void _end(double maxDx) {
    if (_dx >= maxDx * .85) {
      HapticFeedback.mediumImpact();
      widget.onComplete();
    }
    setState(() => _dx = 0);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      button: true,
      label: 'Marcar salida',
      onTap: widget.onComplete,
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, box) {
          final maxDx = box.maxWidth - _thumb - _pad * 2;
          final progress = maxDx <= 0 ? 0.0 : (_dx / maxDx).clamp(0.0, 1.0);
          return GestureDetector(
            onHorizontalDragUpdate: (d) =>
                setState(() => _dx = (_dx + d.delta.dx).clamp(0.0, maxDx)),
            onHorizontalDragEnd: (_) => _end(maxDx),
            child: Container(
              height: _height,
              padding: const EdgeInsets.all(_pad),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(_height / 2),
                color: p.fieldFill,
                border: Border.all(color: p.border),
              ),
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Center(
                    child: Opacity(
                      opacity: 1 - progress,
                      child: Text(
                        'Desliza para marcar salida',
                        style: TextStyle(color: p.textMuted),
                      ),
                    ),
                  ),
                  Transform.translate(
                    offset: Offset(_dx, 0),
                    child: Container(
                      width: _thumb,
                      height: _thumb,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppColors.indigoGradient,
                      ),
                      child: const Icon(
                        Icons.logout_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
