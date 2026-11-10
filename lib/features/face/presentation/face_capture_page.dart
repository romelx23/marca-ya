import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;

import '../application/face_providers.dart';
import '../domain/face_preprocess.dart';
import '../domain/liveness.dart';

/// Captura un rostro para marcar: prueba de vida (parpadear o girar) y devuelve su embedding.
/// Al terminar hace `Navigator.pop(context, embedding)`; si el usuario cancela devuelve null.
class FaceCapturePage extends ConsumerStatefulWidget {
  const FaceCapturePage({super.key});

  @override
  ConsumerState<FaceCapturePage> createState() => _FaceCapturePageState();
}

class _FaceCapturePageState extends ConsumerState<FaceCapturePage> {
  CameraController? _camera;
  Timer? _timer;
  bool _busy = false;
  bool _done = false;
  String _hint = 'Mira a la cámara';
  String? _error;
  final _liveness = LivenessChecker();

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _camera?.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    try {
      final cams = await availableCameras();
      final front = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cams.first,
      );
      final controller = CameraController(
        front,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      _camera = controller;
      _timer = Timer.periodic(
        const Duration(milliseconds: 700),
        (_) => _tick(),
      );
      setState(() {});
    } catch (e) {
      _fail(e);
    }
  }

  Future<void> _tick() async {
    final camera = _camera;
    if (_busy || _done || camera == null || !camera.value.isInitialized) return;
    _busy = true;
    String? path;
    try {
      final shot = await camera.takePicture();
      path = shot.path;
      final face = await ref.read(faceFinderProvider).findInFile(path);
      if (face == null) {
        _say('No veo tu rostro. Acércate a la cámara');
        return;
      }
      _liveness.addObservation(
        eyeOpenProbability: face.eyeOpen,
        yawDegrees: face.yawDegrees,
      );
      if (!_liveness.passed) {
        _say('Parpadea o gira la cabeza despacio');
        return;
      }
      if ((face.eyeOpen ?? 1) < 0.6) {
        _say('Mantén los ojos abiertos');
        return;
      }
      final decoded = img.decodeImage(await File(path).readAsBytes());
      if (decoded == null) {
        _say('No pude leer la captura, intenta de nuevo');
        return;
      }
      final embedder = await ref.read(faceEmbedderProvider.future);
      final embedding = await embedder.embed(
        preprocessFace(img.bakeOrientation(decoded), face.box),
      );
      _done = true;
      _timer?.cancel();
      if (mounted) {
        Navigator.of(context).pop(embedding);
      }
    } catch (e) {
      _fail(e);
    } finally {
      if (path != null) {
        await File(path).delete().catchError((_) => File(path!));
      }
      _busy = false;
    }
  }

  void _say(String hint) {
    if (mounted && _hint != hint) setState(() => _hint = hint);
  }

  void _fail(Object e) {
    _timer?.cancel();
    if (mounted) {
      setState(() => _error = 'No se pudo usar la cámara o el modelo: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final camera = _camera;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Marcar con rostro'),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Expanded(
                child: camera != null && camera.value.isInitialized
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: CameraPreview(camera),
                      )
                    : const Center(child: CircularProgressIndicator()),
              ),
              const SizedBox(height: 16),
              Text(
                _hint,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFFFF6B6B)),
                ),
              ],
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.of(context).pop<List<double>>(null),
                child: const Text('Cancelar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
