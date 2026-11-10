import 'dart:typed_data';

import 'package:tflite_flutter/tflite_flutter.dart';

import '../domain/face_math.dart';
import '../domain/face_preprocess.dart';

/// Calcula el embedding (128 valores normalizados) de un rostro ya preprocesado [3,112,112].
abstract class FaceEmbedder {
  Future<List<double>> embed(Float32List input);
  Future<void> close();
}

/// MobileFaceNet (Qualcomm AI Hub, float, Apache-2.0) ejecutado en el teléfono con TFLite.
class TfliteFaceEmbedder implements FaceEmbedder {
  TfliteFaceEmbedder._(this._interpreter);

  static const String assetPath = 'assets/models/mobilefacenet.tflite';
  static const int embeddingSize = 128;

  final Interpreter _interpreter;

  static Future<TfliteFaceEmbedder> load() async {
    final interpreter = await Interpreter.fromAsset(
      assetPath,
      options: InterpreterOptions()..threads = 2,
    );
    return TfliteFaceEmbedder._(interpreter);
  }

  @override
  Future<List<double>> embed(Float32List input) async {
    final nested = _toNchw(input);
    // El modelo tiene dos entradas (img1, img2). Se pasa el mismo rostro en ambas.
    final output = List.generate(
      2,
      (_) => List<double>.filled(embeddingSize, 0),
    );
    _interpreter.runForMultipleInputs([nested, nested], {0: output});
    return l2Normalize(output[0]);
  }

  @override
  Future<void> close() async {
    _interpreter.close();
  }

  static List<List<List<List<double>>>> _toNchw(Float32List flat) {
    const side = kFaceInputSide;
    const plane = side * side;
    return [
      [
        for (var c = 0; c < 3; c++)
          [
            for (var y = 0; y < side; y++)
              [
                for (var x = 0; x < side; x++)
                  flat[c * plane + y * side + x].toDouble(),
              ],
          ],
      ],
    ];
  }
}
