/// Prueba de vida activa: el empleado debe parpadear o girar la cabeza durante la captura.
///
/// Recibe observaciones por cuadro (probabilidad de ojo abierto y ángulo de giro).
/// Pasa si hubo un parpadeo completo (abierto → cerrado → abierto) o un giro de al menos [minTurnDegrees].
class LivenessChecker {
  LivenessChecker({this.minTurnDegrees = 15});

  final double minTurnDegrees;
  static const double _open = 0.7;
  static const double _closed = 0.3;

  bool _closedSeen = false;
  bool _blinked = false;
  double? _minYaw;
  double? _maxYaw;

  void addObservation({double? eyeOpenProbability, double? yawDegrees}) {
    final p = eyeOpenProbability;
    if (p != null) {
      if (p < _closed) _closedSeen = true;
      if (p > _open && _closedSeen) _blinked = true;
    }
    final yaw = yawDegrees;
    if (yaw != null) {
      _minYaw = (_minYaw == null || yaw < _minYaw!) ? yaw : _minYaw;
      _maxYaw = (_maxYaw == null || yaw > _maxYaw!) ? yaw : _maxYaw;
    }
  }

  bool get blinked => _blinked;

  bool get turned =>
      _minYaw != null &&
      _maxYaw != null &&
      (_maxYaw! - _minYaw!) >= minTurnDegrees;

  bool get passed => blinked || turned;

  void reset() {
    _closedSeen = false;
    _blinked = false;
    _minYaw = null;
    _maxYaw = null;
  }
}
