import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:marca_ya/features/face/domain/face_math.dart';
import 'package:marca_ya/features/face/domain/face_preprocess.dart';
import 'package:marca_ya/features/face/domain/liveness.dart';

void main() {
  group('matemática de embeddings', () {
    test('l2Normalize deja norma 1', () {
      final n = l2Normalize([3, 4]);
      expect(n[0], closeTo(0.6, 1e-9));
      expect(n[1], closeTo(0.8, 1e-9));
    });

    test('cosineSimilarity: idénticos = 1, ortogonales = 0, opuestos = -1', () {
      expect(cosineSimilarity([1, 2, 3], [1, 2, 3]), closeTo(1, 1e-9));
      expect(cosineSimilarity([1, 0], [0, 1]), closeTo(0, 1e-9));
      expect(cosineSimilarity([1, 0], [-1, 0]), closeTo(-1, 1e-9));
    });

    test('vector cero no produce NaN', () {
      expect(l2Normalize([0, 0]), [0, 0]);
      expect(cosineSimilarity([0, 0], [1, 1]), 0);
    });
  });

  group('recorte del rostro', () {
    test(
      'el cuadrado queda dentro de la imagen aunque el rostro esté en el borde',
      () {
        final sq = squareAroundFace(const FaceBox(0, 0, 100, 120), 640, 480);
        expect(sq.left, greaterThanOrEqualTo(0));
        expect(sq.top, greaterThanOrEqualTo(0));
        expect(sq.left + sq.width, lessThanOrEqualTo(640));
        expect(sq.top + sq.height, lessThanOrEqualTo(480));
        expect(sq.width, sq.height);
      },
    );

    test(
      'preprocessFace produce [3,112,112] con valores en 0..1 y orden de canales',
      () {
        final image = img.Image(width: 300, height: 300);
        img.fill(image, color: img.ColorRgb8(255, 0, 0));
        final t = preprocessFace(image, const FaceBox(50, 50, 200, 200));
        expect(t.length, 3 * kFaceInputSide * kFaceInputSide);
        const plane = kFaceInputSide * kFaceInputSide;
        expect(t[0], closeTo(1, 1e-6)); // canal R
        expect(t[plane], closeTo(0, 1e-6)); // canal G
        expect(t[2 * plane], closeTo(0, 1e-6)); // canal B
        expect(t.every((v) => v >= 0 && v <= 1), isTrue);
      },
    );
  });

  group('prueba de vida', () {
    test('sin movimiento no pasa', () {
      final l = LivenessChecker();
      for (var i = 0; i < 10; i++) {
        l.addObservation(eyeOpenProbability: 0.95, yawDegrees: 2);
      }
      expect(l.passed, isFalse);
    });

    test('un parpadeo completo (abierto, cerrado, abierto) pasa', () {
      final l = LivenessChecker();
      l.addObservation(eyeOpenProbability: 0.9);
      l.addObservation(eyeOpenProbability: 0.1);
      expect(l.passed, isFalse);
      l.addObservation(eyeOpenProbability: 0.9);
      expect(l.passed, isTrue);
    });

    test('girar la cabeza al menos 15 grados pasa', () {
      final l = LivenessChecker();
      l.addObservation(yawDegrees: -8);
      l.addObservation(yawDegrees: 4);
      expect(l.passed, isFalse);
      l.addObservation(yawDegrees: 9);
      expect(l.turned, isTrue);
      expect(l.passed, isTrue);
    });

    test('reset borra el progreso', () {
      final l = LivenessChecker()..addObservation(eyeOpenProbability: 0.1);
      l.reset();
      l.addObservation(eyeOpenProbability: 0.9);
      expect(l.passed, isFalse);
    });
  });
}
