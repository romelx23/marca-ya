import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Caja del rostro en píxeles de la imagen original.
class FaceBox {
  const FaceBox(this.left, this.top, this.width, this.height);
  final double left;
  final double top;
  final double width;
  final double height;
}

/// Lado de la entrada del modelo (MobileFaceNet trabaja con 112×112).
const int kFaceInputSide = 112;

/// Cuadrado centrado en el rostro, con margen, recortado a la imagen.
FaceBox squareAroundFace(
  FaceBox box,
  int imageWidth,
  int imageHeight, {
  double margin = 0.2,
}) {
  final side = math.min(
    math.max(box.width, box.height) * (1 + 2 * margin),
    math.min(imageWidth, imageHeight).toDouble(),
  );
  final cx = box.left + box.width / 2;
  final cy = box.top + box.height / 2;
  final left = (cx - side / 2).clamp(0.0, imageWidth - side).toDouble();
  final top = (cy - side / 2).clamp(0.0, imageHeight - side).toDouble();
  return FaceBox(left, top, side, side);
}

/// Convierte el rostro en el tensor que espera el modelo: [3, 112, 112] (canales primero),
/// valores de 0 a 1, en orden R, G, B.
Float32List preprocessFace(img.Image image, FaceBox box) {
  final sq = squareAroundFace(box, image.width, image.height);
  final crop = img.copyCrop(
    image,
    x: sq.left.round(),
    y: sq.top.round(),
    width: sq.width.round(),
    height: sq.height.round(),
  );
  final resized = img.copyResize(
    crop,
    width: kFaceInputSide,
    height: kFaceInputSide,
    interpolation: img.Interpolation.linear,
  );
  const plane = kFaceInputSide * kFaceInputSide;
  final out = Float32List(3 * plane);
  for (var y = 0; y < kFaceInputSide; y++) {
    for (var x = 0; x < kFaceInputSide; x++) {
      final p = resized.getPixel(x, y);
      final i = y * kFaceInputSide + x;
      out[i] = p.r / 255;
      out[plane + i] = p.g / 255;
      out[2 * plane + i] = p.b / 255;
    }
  }
  return out;
}
