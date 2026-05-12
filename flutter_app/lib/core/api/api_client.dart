import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../auth/auth_models.dart';
import '../streak/streak_models.dart';
import '../voice/voice_option.dart';

const _kEnvBaseUrl = String.fromEnvironment('API_BASE_URL');
const _kFallbackBaseUrl = 'http://localhost:8080';

String _resolveBaseUrl(String? override) {
  if (override != null && override.isNotEmpty) return override;
  if (_kEnvBaseUrl.isNotEmpty) return _kEnvBaseUrl;
  return _kFallbackBaseUrl;
}

/// Thrown by [ApiClient._request] for any 4xx/5xx response. Extends
/// [HttpException] so legacy `catch (HttpException)` sites keep working;
/// callers that need the status (e.g. distinguishing a 429 rate-limit
/// from an arbitrary failure) can `is ApiException` and read [statusCode]
/// + [errorCode].
class ApiException extends HttpException {
  ApiException({
    required this.statusCode,
    required this.errorCode,
    required String message,
    this.headers = const {},
  }) : super(message);

  final int statusCode;
  final String errorCode;
  final Map<String, String> headers;

  /// Case-insensitive lookup so callers do not need to know the
  /// `_request`-side convention of lowercasing every header name.
  String? headerValue(String name) => headers[name.toLowerCase()];
}

class ApiClient {
  ApiClient({String? baseUrl, HttpClient? httpClient})
      : baseUrl = _resolveBaseUrl(baseUrl),
        _httpClient = httpClient ?? HttpClient(),
        _ownsClient = httpClient == null;

  final String baseUrl;
  String? _token;
  final HttpClient _httpClient;
  final bool _ownsClient;

  // S3: expose the shared client so wiring code (main.dart) can hand it
  // to LevelApi and avoid two separate HttpClient connection pools to
  // the same backend.
  HttpClient get httpClient => _httpClient;

  /// Releases the underlying [HttpClient] when ApiClient owns it.
  Future<void> dispose() async {
    if (_ownsClient) {
      _httpClient.close(force: true);
    }
  }

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
    return payload['data'] as List<dynamic>? ?? const [];
  }

  Future<Map<String, dynamic>> getPlan() async {
    final payload = await _authed('GET', '/v1/plan');
    return payload['data'] as Map<String, dynamic>;
  }

  Future<List<dynamic>> listCourses() async {
    final payload = await _authed('GET', '/v1/courses');
    return payload['data'] as List<dynamic>? ?? const [];
  }

  Future<List<dynamic>> listCourseModules(String courseId) async {
    final payload = await _authed('GET', '/v1/courses/$courseId/modules');
    return payload['data'] as List<dynamic>? ?? const [];
  }

  Future<List<dynamic>> listModuleSkills(String moduleId) async {
    final payload = await _authed('GET', '/v1/modules/$moduleId/skills');
    return payload['data'] as List<dynamic>? ?? const [];
  }

  Future<List<dynamic>> listModuleExercises(
    String moduleId, {
    String? skillKind,
  }) async {
    final path =
        skillKind != null
            ? '/v1/modules/$moduleId/exercises?skill_kind=$skillKind'
            : '/v1/modules/$moduleId/exercises';
    final payload = await _authed('GET', path);
    return payload['data'] as List<dynamic>? ?? const [];
  }

  Future<List<dynamic>> getExercises(String moduleId) async {
    final payload = await _authed('GET', '/v1/modules/$moduleId/exercises');
    return payload['data'] as List<dynamic>? ?? const [];
  }

  Future<Map<String, dynamic>> getExercise(String exerciseId) async {
    final payload = await _authed('GET', '/v1/exercises/$exerciseId');
    return payload['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createAttempt(
    String exerciseId, {
    String? locale,
  }) async {
    final body = <String, dynamic>{
      'exercise_id': exerciseId,
      'client_platform': 'ios',
      'app_version': '0.1.0',
    };
    if (locale != null && locale.isNotEmpty) {
      body['locale'] = locale;
    }
    final payload = await _authed('POST', '/v1/attempts', body: body);
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
    int? sampleRateHz,
    int? channels,
    String? preferredVoiceId,
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
    final uploadCompleteBody = <String, dynamic>{
      'storage_key':
          upload['storage_key'] as String? ??
          'device-local/$attemptId/$fileName',
      'mime_type': mimeType,
      'duration_ms': durationMs,
      'file_size_bytes': fileSizeBytes,
      'stored_file_path': binaryUploadResult['stored_file_path'] as String?,
    };
    if (sampleRateHz != null && sampleRateHz > 0) {
      uploadCompleteBody['sample_rate_hz'] = sampleRateHz;
    }
    if (channels != null && channels > 0) {
      uploadCompleteBody['channels'] = channels;
    }
    if (preferredVoiceId != null && preferredVoiceId.isNotEmpty) {
      uploadCompleteBody['preferred_voice_id'] = preferredVoiceId;
    }

    await _authed(
      'POST',
      '/v1/attempts/$attemptId/upload-complete',
      body: uploadCompleteBody,
    );
  }

  Future<Map<String, dynamic>> getAttempt(String attemptId) async {
    final payload = await _authed('GET', '/v1/attempts/$attemptId');
    return payload['data'] as Map<String, dynamic>;
  }

  /// Submit objective answers for poslech_* or cteni_* exercises (sync scoring).
  Future<Map<String, dynamic>> submitAnswers(
    String attemptId,
    Map<String, String> answers,
  ) async {
    final payload = await _authed(
      'POST',
      '/v1/attempts/$attemptId/submit-answers',
      body: {'answers': answers},
    );
    return payload['data'] as Map<String, dynamic>;
  }

  /// URI for streaming exercise audio (listening exercises).
  /// Use with AudioSource.uri(client.exerciseAudioUri(id), headers: client.authHeaders).
  Uri exerciseAudioUri(String exerciseId) {
    return Uri.parse('$baseUrl/v1/exercises/$exerciseId/audio');
  }

  /// Auth headers for use with just_audio AudioSource.uri.
  Map<String, String> get authHeaders {
    final t = _token;
    if (t == null) return const {};
    return {'Authorization': 'Bearer $t'};
  }

  /// Inject a token issued out-of-band (e.g. AuthService bootstrap from
  /// SharedPreferences). The legacy [login] method still owns the
  /// learner@example.com/demo123 dev path; this hook is what V17 uses.
  void setAuthToken(String? token) {
    _token = token;
  }

  /// The currently-attached bearer token. Returned for tests + the
  /// AuthService snapshotting flow; do NOT log this value.
  String? get currentToken => _token;

  // ── V17 self-serve learner endpoints ───────────────────────────────────

  Future<AuthSession> signupV17({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final payload = await _v17Request(
      method: 'POST',
      path: '/v1/auth/signup',
      body: {
        'email': email,
        'password': password,
        'display_name': displayName,
      },
    );
    final session = AuthSession.fromJson(payload);
    _token = session.token;
    return session;
  }

  Future<AuthSession> loginV17({
    required String email,
    required String password,
  }) async {
    final payload = await _v17Request(
      method: 'POST',
      path: '/v1/auth/login',
      body: {'email': email, 'password': password},
    );
    final session = AuthSession.fromJson(payload);
    _token = session.token;
    return session;
  }

  /// V25 — Sign in with Apple. The `nonce` is the SHA256-hashed value
  /// the caller already passed to `SignInWithApple.getAppleIDCredential`;
  /// the backend re-uses it as the identity_token replay guard.
  /// `givenName` / `familyName` are only populated on the very first
  /// sign-in and are forwarded as-is.
  ///
  /// Spec: docs/specs/iap-wire-real.md §4.2
  Future<AuthSession> signInWithAppleV25({
    required String identityToken,
    required String authorizationCode,
    required String nonce,
    String? givenName,
    String? familyName,
  }) async {
    final payload = await _v17Request(
      method: 'POST',
      path: '/v1/auth/apple',
      body: {
        'identity_token': identityToken,
        'authorization_code': authorizationCode,
        'nonce': nonce,
        if (givenName != null && givenName.isNotEmpty) 'given_name': givenName,
        if (familyName != null && familyName.isNotEmpty) 'family_name': familyName,
      },
    );
    final session = AuthSession.fromJson(payload);
    _token = session.token;
    return session;
  }

  Future<void> logoutV17() async {
    if (_token == null) return;
    try {
      await _v17Request(method: 'POST', path: '/v1/auth/logout', authed: true);
    } finally {
      _token = null;
    }
  }

  Future<AuthUser> getMeV17() async {
    final payload = await _v17Request(
      method: 'GET',
      path: '/v1/users/me',
      authed: true,
    );
    return AuthUser.fromJson(payload['user'] as Map<String, dynamic>);
  }

  /// Returns the (streak, usage) pair the Home + Profile widgets
  /// render. Reuses the same /v1/users/me endpoint as [getMeV17] so a
  /// single round-trip refreshes everything.
  Future<({StreakSummary streak, DailyUsageSummary usage})> fetchStreakAndUsageV17() async {
    final payload = await _v17Request(
      method: 'GET',
      path: '/v1/users/me',
      authed: true,
    );
    final streakJson = (payload['streak'] as Map<String, dynamic>?) ?? const {};
    final usageJson = (payload['usage_today'] as Map<String, dynamic>?) ?? const {};
    return (
      streak: StreakSummary.fromJson(streakJson),
      usage: DailyUsageSummary.fromJson(usageJson),
    );
  }

  Future<AuthUser> patchMeV17(Map<String, dynamic> updates) async {
    final payload = await _v17Request(
      method: 'PATCH',
      path: '/v1/users/me',
      authed: true,
      body: updates,
    );
    return AuthUser.fromJson(payload['user'] as Map<String, dynamic>);
  }

  Future<void> deleteMeV17() async {
    await _v17Request(method: 'DELETE', path: '/v1/users/me', authed: true);
    _token = null;
  }

  /// Uploads a new avatar image (jpg/png/webp, ≤5 MB) for the current
  /// learner. Returns the new `avatar_asset_id` (storage key) which the
  /// caller threads back into [AuthUser] after [getMeV17] refresh.
  Future<String> uploadAvatarV17(File image) async {
    final t = _token;
    if (t == null) {
      throw AuthException(statusCode: 401, code: 'missing_token', message: 'Not authenticated.');
    }
    final uri = Uri.parse('$baseUrl/v1/users/me/avatar');
    final request = await HttpClient().openUrl('POST', uri);
    final boundary = '----flutter${DateTime.now().microsecondsSinceEpoch}';
    request.headers.set(HttpHeaders.contentTypeHeader, 'multipart/form-data; boundary=$boundary');
    request.headers.set('Authorization', 'Bearer $t');

    final fileBytes = await image.readAsBytes();
    final filename = image.path.split(Platform.pathSeparator).last;
    final mime = _guessImageMime(filename);
    final head = utf8.encode(
      '--$boundary\r\n'
      'Content-Disposition: form-data; name="file"; filename="$filename"\r\n'
      'Content-Type: $mime\r\n\r\n',
    );
    final tail = utf8.encode('\r\n--$boundary--\r\n');
    request.contentLength = head.length + fileBytes.length + tail.length;
    request.add(head);
    request.add(fileBytes);
    request.add(tail);

    final response = await request.close();
    final text = await response.transform(utf8.decoder).join();
    Map<String, dynamic> payload = const {};
    if (text.isNotEmpty) {
      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) payload = decoded;
    }
    if (response.statusCode >= 400) {
      throw AuthException(
        statusCode: response.statusCode,
        code: (payload['error'] as String?) ?? 'http_${response.statusCode}',
        message: (payload['message'] as String?) ?? 'Avatar upload failed.',
      );
    }
    final data = (payload['data'] as Map<String, dynamic>?) ?? const {};
    return (data['image_asset_id'] as String?) ?? '';
  }

  Future<void> deleteAvatarV17() =>
      _v17Request(method: 'DELETE', path: '/v1/users/me/avatar', authed: true);

  Future<void> resendVerifyV17() => _v17Request(
        method: 'POST',
        path: '/v1/auth/resend-verify',
        authed: true,
      );

  Future<void> forgotPasswordV17(String email) => _v17Request(
        method: 'POST',
        path: '/v1/auth/forgot-password',
        body: {'email': email},
      );

  Future<void> resetPasswordV17({
    required String token,
    required String newPassword,
  }) =>
      _v17Request(
        method: 'POST',
        path: '/v1/auth/reset-password',
        body: {'token': token, 'new_password': newPassword},
      );

  Future<void> changePasswordV17({
    required String currentPassword,
    required String newPassword,
  }) =>
      _v17Request(
        method: 'POST',
        path: '/v1/auth/change-password',
        authed: true,
        body: {
          'current_password': currentPassword,
          'new_password': newPassword,
        },
      );

  Future<void> changeEmailV17({
    required String newEmail,
    required String currentPassword,
  }) =>
      _v17Request(
        method: 'POST',
        path: '/v1/users/me/email-change',
        authed: true,
        body: {
          'new_email': newEmail,
          'current_password': currentPassword,
        },
      );

  /// Submits an Apple StoreKit receipt to the V17 backend for
  /// validation. Returns the parsed response payload that includes
  /// `pro_expires_at` + `product_id`. The handler is idempotent —
  /// duplicate transactions return the existing entitlement rather
  /// than 409 — so retries are safe.
  Future<Map<String, dynamic>> verifyAppleReceiptV17({
    required String receipt,
    String? productId,
  }) =>
      _v17Request(
        method: 'POST',
        path: '/v1/iap/apple/verify',
        authed: true,
        body: {
          'receipt': receipt,
          if (productId != null) 'product_id': productId,
        },
      );

  /// V17 endpoints use a flat error envelope `{ error: code, message: text }`
  /// rather than the legacy `{ error: { message: text } }`. _v17Request
  /// translates non-2xx responses into [AuthException] so handlers can
  /// switch on the [AuthException.code].
  Future<Map<String, dynamic>> _v17Request({
    required String method,
    required String path,
    Map<String, dynamic>? body,
    bool authed = false,
  }) async {
    final headers = <String, String>{};
    if (authed) {
      final t = _token;
      if (t == null) {
        throw AuthException(statusCode: 401, code: 'missing_token', message: 'Not authenticated.');
      }
      headers['Authorization'] = 'Bearer $t';
    }
    final client = HttpClient();
    try {
      final uri = Uri.parse('$baseUrl$path');
      final request = await client.openUrl(method, uri);
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json; charset=utf-8');
      headers.forEach(request.headers.set);
      if (body != null) {
        request.write(jsonEncode(body));
      }
      final response = await request.close();
      final text = await response.transform(utf8.decoder).join();
      Map<String, dynamic> payload = const {};
      if (text.isNotEmpty) {
        final decoded = jsonDecode(text);
        if (decoded is Map<String, dynamic>) payload = decoded;
      }
      if (response.statusCode >= 400) {
        throw AuthException(
          statusCode: response.statusCode,
          code: payload['error'] as String? ?? 'http_${response.statusCode}',
          message: payload['message'] as String? ?? 'Request failed.',
        );
      }
      return payload;
    } finally {
      client.close(force: false);
    }
  }

  /// Submit written text for psani_1_formular or psani_2_email.
  /// [answers] = 3 strings for psani_1, [text] = full email for psani_2.
  /// [preferredVoiceId] is optional; empty/null → backend uses default voice.
  Future<void> submitText(
    String attemptId, {
    List<String>? answers,
    String? text,
    String? preferredVoiceId,
  }) async {
    final body = <String, dynamic>{};
    if (answers != null) body['answers'] = answers;
    if (text != null) body['text'] = text;
    if (preferredVoiceId != null && preferredVoiceId.isNotEmpty) {
      body['preferred_voice_id'] = preferredVoiceId;
    }
    await _authed('POST', '/v1/attempts/$attemptId/submit-text', body: body);
  }

  /// Submits a dictation attempt (V18 — psani_3_dictation).
  ///
  /// [sentences] must contain exactly as many entries as the exercise has,
  /// keyed by 0-based [DictationSentenceSubmission.idx]. Backend caps the body
  /// at 16 KB and each sentence text at 200 runes; mismatches return
  /// `invalid_sentence_count` or `sentence_too_long` error codes.
  Future<void> submitDictation(
    String attemptId, {
    required List<DictationSentenceSubmission> sentences,
  }) async {
    final body = <String, dynamic>{
      'sentences': sentences
          .map((s) => {
                'idx': s.idx,
                'text': s.text,
                'replay_count': s.replayCount,
              })
          .toList(),
    };
    await _authed('POST', '/v1/attempts/$attemptId/submit-text', body: body);
  }

  /// V18.1: One sentence in a dictation OCR submission. AssetID + Text are the
  /// preview-confirm pair (text is what the learner edited after the OCR
  /// returned). For the "both" submission_mode, learners may also submit
  /// type-only sentences in the same payload — those rows have empty AssetID.
  /// Sends a single handwriting photo for OCR preview (V18.1).
  /// Returns recognized text (may be empty on OCR failure) and the asset_id
  /// the caller echoes back at submitDictationOCR time.
  Future<DictationOCRPreview> dictationOCRPreview({
    required String attemptId,
    required int idx,
    required File image,
  }) async {
    final t = _token;
    if (t == null) {
      throw AuthException(statusCode: 401, code: 'missing_token', message: 'Not authenticated.');
    }
    final uri = Uri.parse('$baseUrl/v1/attempts/$attemptId/dictation-ocr-preview');
    final request = await HttpClient().openUrl('POST', uri);
    final boundary = '----flutter${DateTime.now().microsecondsSinceEpoch}';
    request.headers.set(HttpHeaders.contentTypeHeader, 'multipart/form-data; boundary=$boundary');
    request.headers.set('Authorization', 'Bearer $t');

    final fileBytes = await image.readAsBytes();
    final filename = image.path.split(Platform.pathSeparator).last;
    final mime = _guessImageMime(filename);
    final idxField = utf8.encode(
      '--$boundary\r\n'
      'Content-Disposition: form-data; name="idx"\r\n\r\n'
      '$idx\r\n',
    );
    final fileHead = utf8.encode(
      '--$boundary\r\n'
      'Content-Disposition: form-data; name="image"; filename="$filename"\r\n'
      'Content-Type: $mime\r\n\r\n',
    );
    final tail = utf8.encode('\r\n--$boundary--\r\n');
    request.contentLength = idxField.length + fileHead.length + fileBytes.length + tail.length;
    request.add(idxField);
    request.add(fileHead);
    request.add(fileBytes);
    request.add(tail);

    final response = await request.close();
    final text = await response.transform(utf8.decoder).join();
    Map<String, dynamic> payload = const {};
    if (text.isNotEmpty) {
      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) payload = decoded;
    }
    if (response.statusCode >= 400) {
      final errMap = (payload['error'] as Map<String, dynamic>?) ?? const {};
      throw AuthException(
        statusCode: response.statusCode,
        code: (errMap['code'] as String?) ?? 'http_${response.statusCode}',
        message: (errMap['message'] as String?) ?? 'OCR preview failed.',
      );
    }
    final data = (payload['data'] as Map<String, dynamic>?) ?? const {};
    return DictationOCRPreview(
      idx: (data['idx'] as num?)?.toInt() ?? idx,
      text: (data['text'] as String?) ?? '',
      assetId: (data['asset_id'] as String?) ?? '',
    );
  }

  /// Submits a dictation OCR attempt (V18.1 — psani_3_dictation, multipart).
  ///
  /// Each [DictationOCRSentenceSubmission] carries the learner-confirmed text,
  /// the asset_id returned by [dictationOCRPreview], and the optional replay
  /// counter. Backend re-uses the V18 deterministic Levenshtein scorer so
  /// scoring parity holds with [submitDictation].
  Future<void> submitDictationOCR(
    String attemptId, {
    required List<DictationOCRSentenceSubmission> sentences,
  }) async {
    final t = _token;
    if (t == null) {
      throw AuthException(statusCode: 401, code: 'missing_token', message: 'Not authenticated.');
    }
    final uri = Uri.parse('$baseUrl/v1/attempts/$attemptId/submit-dictation-ocr');
    final request = await HttpClient().openUrl('POST', uri);
    final boundary = '----flutter${DateTime.now().microsecondsSinceEpoch}';
    request.headers.set(HttpHeaders.contentTypeHeader, 'multipart/form-data; boundary=$boundary');
    request.headers.set('Authorization', 'Bearer $t');

    final rowsJson = jsonEncode(sentences
        .map((s) => {
              'idx': s.idx,
              'text': s.text,
              'asset_id': s.assetId,
              'replay_count': s.replayCount,
            })
        .toList());
    final field = utf8.encode(
      '--$boundary\r\n'
      'Content-Disposition: form-data; name="sentences"\r\n'
      'Content-Type: application/json; charset=utf-8\r\n\r\n'
      '$rowsJson\r\n',
    );
    final tail = utf8.encode('--$boundary--\r\n');
    request.contentLength = field.length + tail.length;
    request.add(field);
    request.add(tail);

    final response = await request.close();
    final text = await response.transform(utf8.decoder).join();
    Map<String, dynamic> payload = const {};
    if (text.isNotEmpty) {
      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) payload = decoded;
    }
    if (response.statusCode >= 400) {
      final errMap = (payload['error'] as Map<String, dynamic>?) ?? const {};
      throw AuthException(
        statusCode: response.statusCode,
        code: (errMap['code'] as String?) ?? 'http_${response.statusCode}',
        message: (errMap['message'] as String?) ?? 'OCR submit failed.',
      );
    }
  }

  /// Requests a short-lived ElevenLabs signed session URL for an interview.
  /// [selectedOption] is the label chosen by the learner (choice_explain type only).
  /// Returns an InterviewTokenResponse with signed_url and expires_in.
  Future<Map<String, dynamic>> getInterviewToken({
    required String exerciseId,
    required String attemptId,
    String? selectedOption,
  }) async {
    final body = <String, dynamic>{
      'exercise_id': exerciseId,
      'attempt_id': attemptId,
    };
    if (selectedOption != null && selectedOption.isNotEmpty) {
      body['selected_option'] = selectedOption;
    }
    final payload = await _authed(
      'POST',
      '/v1/interview-sessions/token',
      body: body,
    );
    return payload['data'] as Map<String, dynamic>;
  }

  /// Submits a completed interview session transcript for async LLM scoring.
  /// [turns] is the list of conversation turns accumulated client-side.
  /// Returns the attempt map (status=scoring).
  Future<Map<String, dynamic>> submitInterview(
    String attemptId, {
    required List<Map<String, dynamic>> turns,
    required int durationSec,
  }) async {
    final path = '/v1/attempts/$attemptId/submit-interview';
    debugPrint(
      'ApiClient submitInterview POST $baseUrl$path turns=${turns.length} duration=$durationSec',
    );
    try {
      final payload = await _authed(
        'POST',
        path,
        body: {'transcript': turns, 'duration_sec': durationSec},
      );
      debugPrint('ApiClient submitInterview accepted attempt=$attemptId');
      return payload['data'] as Map<String, dynamic>;
    } catch (err, stack) {
      debugPrint('ApiClient submitInterview failed: $err');
      debugPrintStack(stackTrace: stack);
      rethrow;
    }
  }

  /// Returns configured TTS voice list from GET /v1/voices.
  Future<List<VoiceOption>> getVoices() async {
    final payload = await _authed('GET', '/v1/voices');
    final data = payload['data'] as List<dynamic>? ?? const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(VoiceOption.fromJson)
        .toList();
  }

  /// Returns the audio preview URL for the given voice slug.
  /// Returns null on error (e.g. voice not found or TTS unavailable).
  Future<String?> getVoicePreviewUrl(String voiceId) async {
    try {
      final payload = await _authed('GET', '/v1/voices/$voiceId/preview');
      return (payload['data'] as Map<String, dynamic>?)?['url'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<List<dynamic>> getAttempts() async {
    final payload = await _authed('GET', '/v1/attempts');
    return payload['data'] as List<dynamic>? ?? const [];
  }

  /// V19/V20: GET /v1/users/me/progress — per-skill mastery aggregate.
  /// Returns the raw `data` map; ProgressApi handles typed parsing + caching.
  Future<Map<String, dynamic>> getProgress() async {
    final payload = await _authed('GET', '/v1/users/me/progress');
    return (payload['data'] as Map<String, dynamic>?) ?? const {};
  }

  Future<List<dynamic>> listMockTests() async {
    final payload = await _authed('GET', '/v1/mock-tests');
    return payload['data'] as List<dynamic>? ?? const [];
  }

  Future<Map<String, dynamic>> createMockExam({String? mockTestId}) async {
    final body =
        mockTestId != null && mockTestId.isNotEmpty
            ? {'mock_test_id': mockTestId}
            : <String, dynamic>{};
    final payload = await _authed('POST', '/v1/mock-exams', body: body);
    return payload['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getMockExam(String id) async {
    final payload = await _authed('GET', '/v1/mock-exams/$id');
    return payload['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> advanceMockExam(
    String id, {
    required String attemptId,
  }) async {
    final payload = await _authed(
      'POST',
      '/v1/mock-exams/$id/advance',
      body: {'attempt_id': attemptId},
    );
    return payload['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> completeMockExam(String id) async {
    final payload = await _authed('POST', '/v1/mock-exams/$id/complete');
    return payload['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getAttemptReview(String attemptId) async {
    final payload = await _authed('GET', '/v1/attempts/$attemptId/review');
    return payload['data'] as Map<String, dynamic>;
  }

  Future<AudioStreamInfo> getAttemptAudioUrl(String attemptId) async {
    final payload = await _authed('GET', '/v1/attempts/$attemptId/audio/url');
    return AudioStreamInfo.fromJson(payload['data'] as Map<String, dynamic>);
  }

  Future<AudioStreamInfo> getAttemptReviewAudioUrl(String attemptId) async {
    final payload = await _authed(
      'GET',
      '/v1/attempts/$attemptId/review/audio/url',
    );
    return AudioStreamInfo.fromJson(payload['data'] as Map<String, dynamic>);
  }

  Uri exerciseAssetUri(String exerciseId, String assetId) {
    return Uri.parse('$baseUrl/v1/exercises/$exerciseId/assets/$assetId/file');
  }

  /// Constructs URL for a vocabulary/grammar media file using its storage key.
  /// Used by QuizcardWidget to load flashcard images.
  Uri mediaUri(String storageKey) {
    return Uri.parse(
      '$baseUrl/v1/media/file',
    ).replace(queryParameters: {'key': storageKey});
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
    final uri = Uri.parse('$baseUrl$path');
    final request = await _httpClient.openUrl(method, uri);
    request.headers.set(
      HttpHeaders.contentTypeHeader,
      'application/json; charset=utf-8',
    );
    headers?.forEach(request.headers.set);
    if (body != null) {
      // Use write() so Dart picks up charset=utf-8 from Content-Type and
      // encodes with UTF-8 rather than the default latin1 IOSink encoding.
      // This prevents ArgumentError for Czech characters (č, ž, etc.)
      // whose code points exceed the latin1 range (>U+00FF).
      request.write(jsonEncode(body));
    }
    final response = await request.close();
    final text = await response.transform(utf8.decoder).join();
    final payload = jsonDecode(text) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      // Two backend error shapes:
      //   {"error":{"code":..,"message":..}}      (writeError envelope)
      //   {"error":"<code>","message":"<text>"}   (auth gates: email_verify_required, etc.)
      final err = payload['error'];
      String? msg;
      String? code;
      if (err is Map) {
        msg = err['message'] as String?;
        code = err['code'] as String?;
      } else if (err is String) {
        code = err;
      }
      msg ??= payload['message'] as String?;
      code ??= 'http_${response.statusCode}';
      final responseHeaders = <String, String>{};
      response.headers.forEach((name, values) {
        if (values.isNotEmpty) responseHeaders[name.toLowerCase()] = values.first;
      });
      throw ApiException(
        statusCode: response.statusCode,
        errorCode: code,
        message: msg ?? 'Request failed.',
        headers: responseHeaders,
      );
    }
    return payload;
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

String _guessImageMime(String filename) {
  final lower = filename.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.heic') || lower.endsWith('.heif')) return 'image/heic';
  return 'image/jpeg';
}

class AudioStreamInfo {
  AudioStreamInfo({
    required this.url,
    required this.mimeType,
    required this.expiresAt,
  });

  factory AudioStreamInfo.fromJson(Map<String, dynamic> json) {
    final expiresRaw = json['expires_at'] as String?;
    return AudioStreamInfo(
      url: Uri.parse(json['url'] as String),
      mimeType: (json['mime_type'] as String?) ?? '',
      expiresAt:
          expiresRaw == null || expiresRaw.isEmpty
              ? DateTime.now().add(const Duration(minutes: 10))
              : DateTime.parse(expiresRaw),
    );
  }

  final Uri url;
  final String mimeType;
  final DateTime expiresAt;

  bool get isExpiringSoon =>
      expiresAt.difference(DateTime.now()).inSeconds < 60;
}

// V18: One sentence submitted as part of a dictation attempt.
// `replayCount` is telemetry only — backend stores it in attempt details_json
// and never gates or modifies the score based on it.
class DictationSentenceSubmission {
  const DictationSentenceSubmission({
    required this.idx,
    required this.text,
    this.replayCount = 0,
  });

  final int idx;
  final String text;
  final int replayCount;
}

// V18.1: Response from POST /v1/attempts/:id/dictation-ocr-preview.
// `text` is empty when OCR fails; the learner edits or retakes from the UI.
class DictationOCRPreview {
  const DictationOCRPreview({
    required this.idx,
    required this.text,
    required this.assetId,
  });

  final int idx;
  final String text;
  final String assetId;
}

// V18.1: One sentence in a dictation OCR submission. AssetID + Text are the
// preview-confirm pair (text is what the learner edited after the OCR
// returned). For the "both" submission_mode, learners may also submit
// type-only sentences in the same payload — those rows have empty AssetID.
class DictationOCRSentenceSubmission {
  const DictationOCRSentenceSubmission({
    required this.idx,
    required this.text,
    this.assetId = '',
    this.replayCount = 0,
  });

  final int idx;
  final String text;
  final String assetId;
  final int replayCount;
}
