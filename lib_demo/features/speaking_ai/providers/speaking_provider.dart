import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:app_czech/core/supabase/supabase_config.dart';
import 'package:app_czech/features/speaking_ai/providers/blob_fetch_stub.dart'
    if (dart.library.html) 'package:app_czech/features/speaking_ai/providers/blob_fetch_web.dart';

// ── State ─────────────────────────────────────────────────────────────────────

enum SpeakingStatus {
  idle,
  recording,
  recorded,
  uploading,
  uploaded,
  error,
}

class SpeakingState {
  const SpeakingState({
    this.status = SpeakingStatus.idle,
    this.audioPath,
    this.audioFormat,
    this.attemptId,
    this.errorMessage,
    this.amplitudes = const [],
  });

  final SpeakingStatus status;
  final String? audioPath;
  final String? audioFormat;
  final String? attemptId;
  final String? errorMessage;
  final List<double> amplitudes; // 0.0–1.0, recent N samples

  SpeakingState copyWith({
    SpeakingStatus? status,
    String? audioPath,
    String? audioFormat,
    String? attemptId,
    String? errorMessage,
    List<double>? amplitudes,
  }) {
    return SpeakingState(
      status: status ?? this.status,
      audioPath: audioPath ?? this.audioPath,
      audioFormat: audioFormat ?? this.audioFormat,
      attemptId: attemptId ?? this.attemptId,
      errorMessage: errorMessage ?? this.errorMessage,
      amplitudes: amplitudes ?? this.amplitudes,
    );
  }
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class SpeakingSessionNotifier extends StateNotifier<SpeakingState> {
  SpeakingSessionNotifier() : super(const SpeakingState());

  final _recorder = AudioRecorder();
  var _disposed = false;
  var _pollingGeneration = 0;

  // How many amplitude samples to keep for waveform display
  static const _maxAmplitudeSamples = 30;

  Future<bool> hasPermission() async {
    // Web doesn't need explicit permission request via this API
    if (kIsWeb) return true;
    return _recorder.hasPermission();
  }

  Future<void> startRecording() async {
    if (state.status == SpeakingStatus.recording) return;

    final hasPerms = await hasPermission();
    if (!mounted || _disposed) return;
    if (!hasPerms) {
      _setStateSafely(state.copyWith(
        status: SpeakingStatus.error,
        errorMessage:
            'Cần quyền truy cập micro. Vui lòng cho phép trong Cài đặt.',
      ));
      return;
    }

    final profile = await _selectRecordingProfile();
    if (!mounted || _disposed) return;

    String path;
    if (kIsWeb) {
      path =
          'speaking_${DateTime.now().millisecondsSinceEpoch}.${profile.extension}';
    } else {
      final dir = await getTemporaryDirectory();
      path =
          '${dir.path}/speaking_${DateTime.now().millisecondsSinceEpoch}.${profile.extension}';
    }

    await _recorder.start(
      RecordConfig(
        encoder: profile.encoder,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: path,
    );

    if (!mounted || _disposed) return;
    _setStateSafely(state.copyWith(
      status: SpeakingStatus.recording,
      audioPath: path,
      audioFormat: profile.format,
      amplitudes: [],
    ));

    // Poll amplitude for waveform
    _startAmplitudePolling(++_pollingGeneration);
  }

  Future<void> stopRecording() async {
    if (state.status != SpeakingStatus.recording) return;
    _pollingGeneration++;
    final stoppedPath = await _recorder.stop();
    if (!mounted || _disposed) return;
    _setStateSafely(state.copyWith(
      status: SpeakingStatus.recorded,
      audioPath: (stoppedPath != null && stoppedPath.isNotEmpty)
          ? stoppedPath
          : state.audioPath,
    ));
  }

  /// User pressed "Ghi lại" — deletes the temp file and resets to idle.
  void discardRecording() {
    _pollingGeneration++;
    final path = state.audioPath;
    if (path != null && !kIsWeb) {
      try {
        File(path).deleteSync();
      } catch (_) {}
    }
    _setStateSafely(const SpeakingState());
  }

  /// Reset UI state. Safe to call even during upload (called from dispose
  /// only when not uploading). After a successful upload the state stays at
  /// [SpeakingStatus.uploaded] until the next widget initialises.
  void resetToIdle() {
    _pollingGeneration++;
    _setStateSafely(const SpeakingState());
  }

  /// Restore state when navigating back to a previously answered question.
  /// [value] may be a local file path OR a UUID attempt_id (already uploaded).
  void restoreRecording(String value) {
    final isAttemptId = _looksLikeAttemptId(value);
    if (isAttemptId) {
      _setStateSafely(SpeakingState(
        status: SpeakingStatus.uploaded,
        attemptId: value,
      ));
    } else {
      _setStateSafely(SpeakingState(
        status: SpeakingStatus.recorded,
        audioPath: value,
        audioFormat: _inferAudioFormatFromPath(value),
      ));
    }
  }

  static bool _looksLikeAttemptId(String value) {
    // UUID v4 pattern — not a file path or blob URL
    final uuidPattern = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    );
    return uuidPattern.hasMatch(value);
  }

  Future<void> submitRecording({
    required String lessonId,
    required String questionId,
    String? exerciseId,
    String? examAttemptId,
  }) async {
    if (!mounted) return;
    if (state.audioPath == null) return;

    _setStateSafely(state.copyWith(status: SpeakingStatus.uploading));

    final audioPath = state.audioPath!;
    final audioFormat =
        state.audioFormat ?? _inferAudioFormatFromPath(audioPath);
    try {
      String? resultAttemptId;

      if (kIsWeb) {
        resultAttemptId = await _uploadWeb(
          audioPath: audioPath,
          audioFormat: audioFormat,
          lessonId: lessonId,
          questionId: questionId,
          exerciseId: exerciseId,
          examAttemptId: examAttemptId,
        );
      } else {
        resultAttemptId = await _uploadNative(
          audioPath: audioPath,
          audioFormat: audioFormat,
          lessonId: lessonId,
          questionId: questionId,
          exerciseId: exerciseId,
          examAttemptId: examAttemptId,
        );
      }

      if (!mounted) return;
      _setStateSafely(state.copyWith(
        status: SpeakingStatus.uploaded,
        attemptId: resultAttemptId,
      ));
    } catch (e) {
      if (!mounted) return;
      _setStateSafely(state.copyWith(
        status: SpeakingStatus.error,
        errorMessage: _mapUploadError(e, examAttemptId: examAttemptId),
      ));
    }
  }

  Future<String> _uploadNative({
    required String audioPath,
    required String? audioFormat,
    required String lessonId,
    required String questionId,
    String? exerciseId,
    String? examAttemptId,
  }) async {
    final file = File(audioPath);
    final bytes = await file.readAsBytes();
    return _callUploadFunction(
      bytes: bytes,
      audioFormat: audioFormat,
      lessonId: lessonId,
      questionId: questionId,
      exerciseId: exerciseId,
      examAttemptId: examAttemptId,
    );
  }

  Future<String> _uploadWeb({
    required String audioPath,
    required String? audioFormat,
    required String lessonId,
    required String questionId,
    String? exerciseId,
    String? examAttemptId,
  }) async {
    // Web: audioPath is a blob URL — fetch actual bytes before uploading.
    Uint8List bytes;
    try {
      bytes = await fetchBlobBytes(audioPath);
    } catch (_) {
      bytes = Uint8List(0);
    }
    return _callUploadFunction(
      bytes: bytes,
      audioFormat: audioFormat,
      lessonId: lessonId,
      questionId: questionId,
      exerciseId: exerciseId,
      examAttemptId: examAttemptId,
    );
  }

  Future<String> _callUploadFunction({
    required Uint8List bytes,
    required String? audioFormat,
    required String lessonId,
    required String questionId,
    String? exerciseId,
    String? examAttemptId,
  }) async {
    _logMockTestIosAudioFormat(audioFormat, bytes.length, examAttemptId);

    // Use a flag instead of re-throwing inside catch — that way genuine
    // network/HTTP failures still fall through to the DB insert fallback,
    // while an explicit "audio rejected" response from the edge function
    // propagates as an error to the caller.
    String? audioRejectedReason;
    Object? requestFailure;

    try {
      final response = await _invokeUploadFunction(
        bytes: bytes,
        audioFormat: audioFormat,
        lessonId: lessonId,
        questionId: questionId,
        exerciseId: exerciseId,
        examAttemptId: examAttemptId,
      );
      final data = response.data as Map<String, dynamic>?;
      final attemptId = data?['attempt_id'] as String?;
      final responseError = data?['error'] as String?;
      if (attemptId != null && responseError == null) return attemptId;
      if (responseError != null) {
        audioRejectedReason = responseError;
      }
    } catch (error) {
      requestFailure = error;
      if (examAttemptId != null &&
          _isExamAttemptSchemaMismatch(error.toString())) {
        try {
          final retryResponse = await _invokeUploadFunction(
            bytes: bytes,
            audioFormat: audioFormat,
            lessonId: lessonId,
            questionId: questionId,
            exerciseId: exerciseId,
          );
          final retryData = retryResponse.data as Map<String, dynamic>?;
          final retryAttemptId = retryData?['attempt_id'] as String?;
          final retryError = retryData?['error'] as String?;
          if (retryAttemptId != null && retryError == null) {
            return retryAttemptId;
          }
          if (retryError != null) {
            audioRejectedReason = retryError;
          }
        } catch (_) {
          // Fall through to direct DB fallback below.
        }
      }
      // Network error or edge function not deployed — surface the failure to
      // the recording UI instead of creating a synthetic error attempt row.
    }

    // Edge function explicitly rejected the audio (e.g. empty bytes on web)
    if (audioRejectedReason != null) {
      throw Exception(audioRejectedReason);
    }

    if (requestFailure != null) {
      throw Exception(requestFailure.toString());
    }

    throw Exception('Không thể tải lên bài ghi âm. Vui lòng thử lại.');
  }

  void _logMockTestIosAudioFormat(
    String? audioFormat,
    int byteLength,
    String? examAttemptId,
  ) {
    if (kIsWeb || examAttemptId == null) return;
    if (defaultTargetPlatform != TargetPlatform.iOS) return;

    debugPrint(jsonEncode({
      'event': 'mock_test_speaking_upload_client',
      'platform': 'ios',
      'audio_format': audioFormat ?? 'unknown',
      'bytes': byteLength,
    }));
  }

  Future<dynamic> _invokeUploadFunction({
    required Uint8List bytes,
    required String? audioFormat,
    required String lessonId,
    required String questionId,
    String? exerciseId,
    String? examAttemptId,
  }) {
    return supabase.functions.invoke(
      'speaking-upload',
      body: {
        if (lessonId.isNotEmpty) 'lesson_id': lessonId,
        'question_id': questionId,
        if (exerciseId?.isNotEmpty ?? false) 'exercise_id': exerciseId,
        'audio_b64': bytes.isNotEmpty ? base64Encode(bytes) : '',
        if (audioFormat != null && audioFormat.isNotEmpty)
          'audio_format': audioFormat,
        if (examAttemptId != null) 'exam_attempt_id': examAttemptId,
      },
    );
  }

  bool _isExamAttemptSchemaMismatch(String message) {
    return message.contains('exam_attempt_id') ||
        message.contains('PGRST204') ||
        message.contains('Could not find the');
  }

  String _mapUploadError(
    Object error, {
    String? examAttemptId,
  }) {
    final message = error.toString();

    if (message.contains('No audio data')) {
      return 'Không đọc được dữ liệu ghi âm. Vui lòng ghi lại và thử lại.';
    }

    final missingExamAttemptColumn =
        message.contains('exam_attempt_id') && message.contains('PGRST204');
    if (examAttemptId != null && missingExamAttemptColumn) {
      return 'Server chấm bài nói của exam chưa được cập nhật schema exam_attempt_id. Cần apply migration backend rồi thử lại.';
    }

    if (message.contains('question_id') && message.contains('PGRST204')) {
      return 'Server chấm bài nói đang thiếu cột question_id. Cần cập nhật backend rồi thử lại.';
    }

    if (message.contains('question_id is required')) {
      return 'Thiếu thông tin câu hỏi để nộp bài nói. Vui lòng thoát vào lại bài thi rồi thử lại.';
    }

    return 'Không thể tải lên bài ghi âm. Vui lòng thử lại.';
  }

  void reset() {
    _pollingGeneration++;
    discardRecording();
    _setStateSafely(const SpeakingState());
  }

  Future<_RecordingProfile> _selectRecordingProfile() async {
    final supportsWav = await _recorder.isEncoderSupported(AudioEncoder.wav);
    if (supportsWav) {
      return const _RecordingProfile(
        encoder: AudioEncoder.wav,
        extension: 'wav',
        format: 'wav',
      );
    }

    return const _RecordingProfile(
      encoder: AudioEncoder.aacLc,
      extension: 'm4a',
      format: 'm4a',
    );
  }

  String? _inferAudioFormatFromPath(String? path) {
    if (path == null || path.isEmpty) return null;
    final lower = path.toLowerCase();
    if (lower.endsWith('.wav')) return 'wav';
    if (lower.endsWith('.mp3')) return 'mp3';
    if (lower.endsWith('.m4a')) return 'm4a';
    return null;
  }

  // ── Amplitude polling ────────────────────────────────────────────────────────

  void _startAmplitudePolling(int generation) async {
    while (mounted &&
        !_disposed &&
        generation == _pollingGeneration &&
        state.status == SpeakingStatus.recording) {
      await Future.delayed(const Duration(milliseconds: 80));
      if (!mounted || _disposed || generation != _pollingGeneration) return;
      if (state.status != SpeakingStatus.recording) return;

      try {
        final amp = await _recorder.getAmplitude();
        if (!mounted || _disposed || generation != _pollingGeneration) return;
        final normalized = _normalizeAmplitude(amp.current);
        final updated = [...state.amplitudes, normalized];
        if (updated.length > _maxAmplitudeSamples) {
          updated.removeAt(0);
        }
        _setStateSafely(state.copyWith(amplitudes: updated));
      } catch (_) {
        // Amplitude not available on all platforms — ignore
      }
    }
  }

  void _setStateSafely(SpeakingState next) {
    if (!mounted || _disposed) return;
    // runZonedGuarded is required here: Riverpod notifies listeners via
    // Zone.runBinaryGuarded, which swallows AssertionError from defunct
    // ConsumerStatefulElements and re-routes it through the zone error handler
    // instead of normal exception propagation. A plain try/catch won't intercept
    // those errors; runZonedGuarded creates a child zone whose error handler
    // catches them before they reach the root zone.
    runZonedGuarded(
      () {
        if (!mounted || _disposed) return;
        state = next;
      },
      (_, __) {}, // swallow zone errors from defunct widget listeners
    );
  }

  double _normalizeAmplitude(double db) {
    // dB range approximately -60 to 0; map to 0.0–1.0
    const minDb = -60.0;
    const maxDb = 0.0;
    if (db <= minDb) return 0.05;
    if (db >= maxDb) return 1.0;
    return ((db - minDb) / (maxDb - minDb)).clamp(0.05, 1.0);
  }

  @override
  void dispose() {
    _disposed = true;
    _pollingGeneration++;
    _recorder.dispose();
    super.dispose();
  }
}

class _RecordingProfile {
  const _RecordingProfile({
    required this.encoder,
    required this.extension,
    required this.format,
  });

  final AudioEncoder encoder;
  final String extension;
  final String format;
}

// ── Provider ──────────────────────────────────────────────────────────────────

final speakingSessionProvider =
    StateNotifierProvider<SpeakingSessionNotifier, SpeakingState>(
  (_) => SpeakingSessionNotifier(),
);
