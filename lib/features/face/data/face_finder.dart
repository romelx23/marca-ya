import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../domain/face_preprocess.dart';

/// Un rostro detectado con los datos que usa la prueba de vida.
class DetectedFace {
  const DetectedFace({
    required this.box,
    this.leftEyeOpen,
    this.rightEyeOpen,
    this.yawDegrees,
  });

  final FaceBox box;
  final double? leftEyeOpen;
  final double? rightEyeOpen;
  final double? yawDegrees;

  /// Probabilidad de ojos abiertos (promedio de los disponibles).
  double? get eyeOpen {
    final l = leftEyeOpen;
    final r = rightEyeOpen;
    if (l != null && r != null) return (l + r) / 2;
    return l ?? r;
  }
}

abstract class FaceFinder {
  /// Busca el rostro principal en una imagen guardada en disco. Null si no hay rostro.
  Future<DetectedFace?> findInFile(String path);
  Future<void> close();
}

/// Detección con ML Kit (en el dispositivo, sin enviar la imagen a ningún servicio).
class MlKitFaceFinder implements FaceFinder {
  final FaceDetector _detector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );

  @override
  Future<DetectedFace?> findInFile(String path) async {
    final faces = await _detector.processImage(InputImage.fromFilePath(path));
    if (faces.isEmpty) return null;
    // Si hay varios, se usa el más grande (el que está frente a la cámara).
    final face = faces.reduce((a, b) => _area(a) >= _area(b) ? a : b);
    final r = face.boundingBox;
    return DetectedFace(
      box: FaceBox(r.left, r.top, r.width, r.height),
      leftEyeOpen: face.leftEyeOpenProbability,
      rightEyeOpen: face.rightEyeOpenProbability,
      yawDegrees: face.headEulerAngleY,
    );
  }

  double _area(Face f) => f.boundingBox.width * f.boundingBox.height;

  @override
  Future<void> close() => _detector.close();
}
