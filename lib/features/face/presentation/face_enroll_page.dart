import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../application/face_providers.dart';
import '../data/face_api.dart';
import '../domain/face_preprocess.dart';
import '../domain/liveness.dart';

const int _captureCount = 3;
const String _consentText =
    'Usaremos tu rostro solo para confirmar que eres tú al marcar tu asistencia.\n\n'
    '• No guardamos fotos. Solo un código numérico cifrado, que no permite reconstruir tu rostro.\n'
    '• El reconocimiento se hace en tu teléfono; el servidor recibe únicamente el código.\n'
    '• Si no quieres usar tu rostro, puedes marcar con tu PIN.\n'
    '• Puedes retirar tu consentimiento cuando quieras y se borran tus códigos.';

enum _Step { loading, consent, capture, pin, done }

/// Inscripción facial: consentimiento, captura con prueba de vida y PIN de respaldo.
class FaceEnrollPage extends ConsumerStatefulWidget {
  const FaceEnrollPage({super.key});

  @override
  ConsumerState<FaceEnrollPage> createState() => _FaceEnrollPageState();
}

class _FaceEnrollPageState extends ConsumerState<FaceEnrollPage> {
  _Step _step = _Step.loading;
  String? _error;
  String? _version;
  bool _accepted = false;
  bool _busy = false;
  String _pin = '';
  String _hint = 'Mira a la cámara';
  CameraController? _camera;
  Timer? _timer;
  final _liveness = LivenessChecker();
  final _embeddings = <List<double>>[];
  FaceStatus? _status;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _camera?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final s = await ref.read(faceApiProvider).status();
      if (!mounted) return;
      setState(() {
        _status = s;
        _version = s.currentConsentVersion;
        _step = s.consented ? _Step.capture : _Step.consent;
      });
      if (s.consented) await _startCamera();
    } catch (e) {
      _fail(e);
    }
  }

  Future<void> _acceptConsent() async {
    setState(() => _busy = true);
    try {
      final s = await ref.read(faceApiProvider).consent(_version!);
      if (!mounted) return;
      setState(() {
        _status = s;
        _step = _Step.capture;
      });
      await _startCamera();
    } catch (e) {
      _fail(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _startCamera() async {
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
      _liveness.reset();
      _embeddings.clear();
      _timer?.cancel();
      _timer = Timer.periodic(
        const Duration(milliseconds: 700),
        (_) => _tick(),
      );
      setState(() {});
    } catch (e) {
      _fail(e);
    }
  }

  /// Un ciclo: toma una foto, busca el rostro, verifica la prueba de vida y guarda el embedding.
  Future<void> _tick() async {
    final camera = _camera;
    if (_busy ||
        _step != _Step.capture ||
        camera == null ||
        !camera.value.isInitialized) {
      return;
    }
    _busy = true;
    String? path;
    try {
      final shot = await camera.takePicture();
      path = shot.path;
      final face = await ref.read(faceFinderProvider).findInFile(path);
      if (face == null) {
        return _say('No veo tu rostro. Acércate a la cámara');
      }

      _liveness.addObservation(
        eyeOpenProbability: face.eyeOpen,
        yawDegrees: face.yawDegrees,
      );
      if (!_liveness.passed) {
        return _say('Parpadea o gira la cabeza despacio');
      }
      if ((face.eyeOpen ?? 1) < 0.6) {
        return _say('Mantén los ojos abiertos');
      }

      final decoded = img.decodeImage(await File(path).readAsBytes());
      if (decoded == null) {
        return _say('No pude leer la captura, intenta de nuevo');
      }
      final oriented = img.bakeOrientation(decoded);
      final embedder = await ref.read(faceEmbedderProvider.future);
      _embeddings.add(await embedder.embed(preprocessFace(oriented, face.box)));

      if (_embeddings.length >= _captureCount) {
        _timer?.cancel();
        if (!mounted) return;
        setState(() => _step = _Step.pin);
        return;
      }
      _say(
        'Captura ${_embeddings.length} de $_captureCount. Sigue mirando la cámara',
      );
    } catch (e) {
      _timer?.cancel();
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

  Future<void> _savePin() async {
    if (!RegExp(r'^\d{4,6}$').hasMatch(_pin)) {
      setState(() => _error = 'El PIN debe tener de 4 a 6 dígitos');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final s = await ref.read(faceApiProvider).enroll(_embeddings, _pin);
      await _camera?.dispose();
      _camera = null;
      if (!mounted) return;
      setState(() {
        _status = s;
        _step = _Step.done;
      });
    } catch (e) {
      _fail(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _revoke() async {
    setState(() => _busy = true);
    try {
      final s = await ref.read(faceApiProvider).revoke();
      if (!mounted) return;
      setState(() {
        _status = s;
        _step = _Step.consent;
        _accepted = false;
      });
    } catch (e) {
      _fail(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _fail(Object e) {
    if (!mounted) return;
    setState(() {
      _error = e is ApiException ? e.message : e.toString();
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi rostro'),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: switch (_step) {
            _Step.loading => const Center(child: CircularProgressIndicator()),
            _Step.consent => _consentView(p),
            _Step.capture => _captureView(p),
            _Step.pin => _pinView(p),
            _Step.done => _doneView(p),
          },
        ),
      ),
    );
  }

  Widget _errorText(AppPalette p) => _error == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFFF6B6B)),
          ),
        );

  Widget _consentView(AppPalette p) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Consentimiento',
        style: Theme.of(
          context,
        ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 16),
      Expanded(
        child: SingleChildScrollView(
          child: Text(
            _consentText,
            style: TextStyle(color: p.textMuted, height: 1.5),
          ),
        ),
      ),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        value: _accepted,
        onChanged: _busy ? null : (v) => setState(() => _accepted = v ?? false),
        title: const Text('Acepto el uso de mi rostro para marcar asistencia'),
        controlAffinity: ListTileControlAffinity.leading,
      ),
      _errorText(p),
      const SizedBox(height: 8),
      FilledButton(
        key: const Key('face-consent-accept'),
        onPressed: (_accepted && !_busy) ? _acceptConsent : null,
        child: Text(_busy ? 'Guardando…' : 'Acepto y continúo'),
      ),
    ],
  );

  Widget _captureView(AppPalette p) {
    final camera = _camera;
    return Column(
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
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'Captura ${_embeddings.length} de $_captureCount',
          style: TextStyle(color: p.textMuted),
        ),
        _errorText(p),
      ],
    );
  }

  Widget _pinView(AppPalette p) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'PIN de respaldo',
        style: Theme.of(
          context,
        ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 8),
      Text(
        'Lo usarás si el rostro no se reconoce. Entre 4 y 6 dígitos.',
        style: TextStyle(color: p.textMuted, height: 1.4),
      ),
      const SizedBox(height: 24),
      TextField(
        key: const Key('face-pin'),
        keyboardType: TextInputType.number,
        obscureText: true,
        maxLength: 6,
        onChanged: (v) => _pin = v,
        decoration: const InputDecoration(labelText: 'PIN'),
      ),
      _errorText(p),
      const Spacer(),
      FilledButton(
        key: const Key('face-pin-save'),
        onPressed: _busy ? null : _savePin,
        child: Text(_busy ? 'Guardando…' : 'Guardar'),
      ),
    ],
  );

  Widget _doneView(AppPalette p) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Spacer(),
      Icon(
        Icons.verified_user_outlined,
        size: 72,
        color: Theme.of(context).colorScheme.secondary,
      ),
      const SizedBox(height: 16),
      Text(
        'Rostro registrado',
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 8),
      Text(
        '${_status?.templates ?? _captureCount} capturas cifradas guardadas. PIN definido.',
        textAlign: TextAlign.center,
        style: TextStyle(color: p.textMuted),
      ),
      const Spacer(),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Listo'),
      ),
      const SizedBox(height: 8),
      TextButton(
        onPressed: _busy ? null : _revoke,
        child: const Text('Retirar mi consentimiento y borrar mi rostro'),
      ),
    ],
  );
}
