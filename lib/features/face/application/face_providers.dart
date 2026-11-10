import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../data/face_api.dart';
import '../data/face_embedder.dart';
import '../data/face_finder.dart';

final faceApiProvider = Provider<FaceApi>(
  (ref) => FaceApi(
    ref.watch(apiClientProvider),
    () => ref.read(authControllerProvider).valueOrNull?.token,
  ),
);

final faceFinderProvider = Provider<FaceFinder>((ref) {
  final finder = MlKitFaceFinder();
  ref.onDispose(finder.close);
  return finder;
});

/// Carga el modelo una sola vez (es un archivo de ~4 MB en los assets).
final faceEmbedderProvider = FutureProvider<FaceEmbedder>((ref) async {
  final embedder = await TfliteFaceEmbedder.load();
  ref.onDispose(embedder.close);
  return embedder;
});
