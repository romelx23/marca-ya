import 'dart:math' as math;

/// Escala el vector a norma 1 (el servidor también normaliza; así ambos lados quedan iguales).
List<double> l2Normalize(List<double> v) {
  final norm = math.sqrt(v.fold<double>(0, (s, x) => s + x * x));
  if (norm == 0) return List.of(v);
  return [for (final x in v) x / norm];
}

/// Similitud coseno entre dos vectores de la misma longitud (1.0 = idénticos).
double cosineSimilarity(List<double> a, List<double> b) {
  assert(a.length == b.length, 'Los vectores deben tener la misma longitud');
  var dot = 0.0, na = 0.0, nb = 0.0;
  for (var i = 0; i < a.length; i++) {
    dot += a[i] * b[i];
    na += a[i] * a[i];
    nb += b[i] * b[i];
  }
  final denom = math.sqrt(na) * math.sqrt(nb);
  return denom == 0 ? 0 : dot / denom;
}
