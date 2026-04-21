import 'dart:convert';
import 'dart:io';

class ApiClient {
  ApiClient({this.baseUrl = 'http://localhost:8080'});

  final String baseUrl;
  String? _token;

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await _request(
      method: 'POST',
      path: '/v1/auth/login',
      body: {'email': email, 'password': password},
    );

    _token = response['data']['access_token'] as String;
    return response['data'] as Map<String, dynamic>;
  }

  Future<List<dynamic>> getModules() async {
    final payload = await _authed('GET', '/v1/modules');
    return payload['data'] as List<dynamic>;
  }

  Future<List<dynamic>> getExercises(String moduleId) async {
    final payload = await _authed('GET', '/v1/modules/$moduleId/exercises');
    return payload['data'] as List<dynamic>;
  }

  Future<Map<String, dynamic>> getExercise(String exerciseId) async {
    final payload = await _authed('GET', '/v1/exercises/$exerciseId');
    return payload['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createAttempt(String exerciseId) async {
    final payload = await _authed(
      'POST',
      '/v1/attempts',
      body: {
        'exercise_id': exerciseId,
        'client_platform': 'ios',
        'app_version': '0.1.0',
      },
    );
    return payload['data']['attempt'] as Map<String, dynamic>;
  }

  Future<void> markRecordingStarted(String attemptId) async {
    await _authed(
      'POST',
      '/v1/attempts/$attemptId/recording-started',
      body: {'recording_started_at': DateTime.now().toUtc().toIso8601String()},
    );
  }

  Future<void> submitRecordedAudio(
    String attemptId, {
    required String audioPath,
    required String mimeType,
    required int fileSizeBytes,
    int durationMs = 25000,
    int sampleRateHz = 44100,
    int channels = 1,
  }) async {
    final uploadPayload = await _authed(
      'POST',
      '/v1/attempts/$attemptId/upload-url',
      body: {
        'mime_type': mimeType,
        'file_size_bytes': fileSizeBytes,
        'duration_ms': durationMs,
      },
    );
    final upload = uploadPayload['data']['upload'] as Map<String, dynamic>;
    final binaryUploadResult = await _uploadBinary(
      method: upload['method'] as String,
      url: upload['url'] as String,
      headers: (upload['headers'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, value as String),
      ),
      audioPath: audioPath,
      fileSizeBytes: fileSizeBytes,
    );
    final fileName = audioPath.split(Platform.pathSeparator).last;
    await _authed(
      'POST',
      '/v1/attempts/$attemptId/upload-complete',
      body: {
        'storage_key':
            upload['storage_key'] as String? ??
            'device-local/$attemptId/$fileName',
        'mime_type': mimeType,
        'duration_ms': durationMs,
        'sample_rate_hz': sampleRateHz,
        'channels': channels,
        'file_size_bytes': fileSizeBytes,
        'stored_file_path': binaryUploadResult['stored_file_path'] as String?,
      },
    );
  }

  Future<Map<String, dynamic>> getAttempt(String attemptId) async {
    final payload = await _authed('GET', '/v1/attempts/$attemptId');
    return payload['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> _authed(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    if (_token == null) {
      throw const HttpException('Not authenticated.');
    }

    return _request(
      method: method,
      path: path,
      body: body,
      headers: {'Authorization': 'Bearer $_token'},
    );
  }

  Future<Map<String, dynamic>> _request({
    required String method,
    required String path,
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    final client = HttpClient();
    try {
      final uri = Uri.parse('$baseUrl$path');
      final request = await client.openUrl(method, uri);
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      headers?.forEach(request.headers.set);
      if (body != null) {
        request.write(jsonEncode(body));
      }
      final response = await request.close();
      final text = await response.transform(utf8.decoder).join();
      final payload = jsonDecode(text) as Map<String, dynamic>;
      if (response.statusCode >= 400) {
        throw HttpException(
          payload['error']?['message'] as String? ?? 'Request failed.',
        );
      }
      return payload;
    } finally {
      client.close(force: true);
    }
  }

  Future<Map<String, dynamic>> _uploadBinary({
    required String method,
    required String url,
    required Map<String, String> headers,
    required String audioPath,
    required int fileSizeBytes,
  }) async {
    final file = File(audioPath);
    final client = HttpClient();
    try {
      final uri = Uri.parse(url);
      final request = await client.openUrl(method, uri);
      headers.forEach(request.headers.set);
      if (_token != null && url.startsWith(baseUrl)) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $_token');
      }
      request.headers.contentLength = fileSizeBytes;
      await request.addStream(file.openRead());
      final response = await request.close();
      final text = await response.transform(utf8.decoder).join();
      if (response.statusCode >= 400) {
        throw HttpException(text.isEmpty ? 'Binary upload failed.' : text);
      }
      if (text.isEmpty) {
        return const {};
      }
      return (jsonDecode(text) as Map<String, dynamic>)['data']
              as Map<String, dynamic>? ??
          const {};
    } finally {
      client.close(force: true);
    }
  }
}
