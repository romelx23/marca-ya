import '../../../core/api/api_client.dart';

/// Estado del reconocimiento facial del empleado (GET /face/status).
class FaceStatus {
  const FaceStatus({
    required this.currentConsentVersion,
    required this.consented,
    required this.templates,
    required this.pinSet,
  });

  factory FaceStatus.fromJson(Map<String, dynamic> j) => FaceStatus(
    currentConsentVersion: j['currentConsentVersion'] as String,
    consented: j['consented'] as bool,
    templates: (j['templates'] as num).toInt(),
    pinSet: j['pinSet'] as bool,
  );

  final String currentConsentVersion;
  final bool consented;
  final int templates;
  final bool pinSet;
}

/// Cliente de /face. Los embeddings viajan como números; nunca se envían imágenes.
class FaceApi {
  FaceApi(this._client, this._token);

  final ApiClient _client;
  final String? Function() _token;

  Future<FaceStatus> status() async =>
      FaceStatus.fromJson(await _client.get('/face/status', token: _token()));

  Future<FaceStatus> consent(String version) async => FaceStatus.fromJson(
    await _client.post('/face/consent', {'version': version}, token: _token()),
  );

  Future<FaceStatus> enroll(List<List<double>> embeddings, String pin) async =>
      FaceStatus.fromJson(
        await _client.post('/face/enroll', {
          'embeddings': embeddings,
          'pin': pin,
        }, token: _token()),
      );

  Future<FaceStatus> revoke() async => FaceStatus.fromJson(
    await _client.delete('/face/enroll', token: _token()),
  );
}
