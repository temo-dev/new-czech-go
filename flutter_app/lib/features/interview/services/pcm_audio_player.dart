import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

/// Buffers PCM16 chunks and plays them as a WAV file via just_audio.
/// Sprint 1: simple buffer → WAV → play (no streaming).
/// Sprint 2: replaces with Simli sendAudioData() when avatar is added.
class PcmAudioPlayer {
  PcmAudioPlayer({int sampleRate = _defaultSampleRate})
    : _sampleRate = sampleRate;

  final AudioPlayer _player = AudioPlayer();
  final List<int> _pcmBuffer = [];
  bool _playing = false;
  bool _playAgainAfterCurrent = false;
  bool _disposed = false;
  int _sampleRate;

  static const _defaultSampleRate = 16000;
  static const _channels = 1;
  static const _bitsPerSample = 16;

  /// Add a PCM16 chunk to the buffer.
  void addChunk(Uint8List chunk) {
    if (_disposed) return;
    _pcmBuffer.addAll(chunk);
  }

  /// Updates the output sample rate using ElevenLabs metadata, e.g. "pcm_44100".
  void setOutputAudioFormat(String? format) {
    final sampleRate = sampleRateFromElevenLabsFormat(format);
    if (sampleRate != null) {
      _sampleRate = sampleRate;
    }
  }

  /// Play and clear the current buffer. No-op if buffer is empty.
  Future<void> flushAndPlay() async {
    if (_pcmBuffer.isEmpty) return;
    if (_playing) {
      _playAgainAfterCurrent = true;
      return;
    }

    while (_pcmBuffer.isNotEmpty && !_disposed) {
      final pendingBytes = _pcmBuffer.length;
      // V16: trace local audio playback so we can diagnose missed-audio reports.
      // Bytes / sample rate / channels gives effective duration in seconds.
      final approxSec = pendingBytes /
          (_sampleRate * _channels * (_bitsPerSample / 8));
      debugPrint(
        'PcmAudioPlayer.flushAndPlay sampleRate=$_sampleRate '
        'bytes=$pendingBytes approxDurationSec=${approxSec.toStringAsFixed(2)}',
      );
      await _playCurrentBuffer();
      if (!_playAgainAfterCurrent && _pcmBuffer.isEmpty) return;
      _playAgainAfterCurrent = false;
    }
  }

  Future<void> _playCurrentBuffer() async {
    final data = Uint8List.fromList(_pcmBuffer);
    _pcmBuffer.clear();

    // Declare file outside try so finally can clean it up on any code path.
    File? file;
    try {
      _playing = true;
      final wavBytes = wavBytesForTesting(data, sampleRate: _sampleRate);
      final dir = await getTemporaryDirectory();
      file = File(
        '${dir.path}/interview_audio_${DateTime.now().millisecondsSinceEpoch}.wav',
      );
      await file.writeAsBytes(wavBytes);
      await _player.setFilePath(file.path);
      await _player.play();
      await _player.processingStateStream.firstWhere(
        (s) => s == ProcessingState.completed || s == ProcessingState.idle,
      );
    } catch (err) {
      // Audio playback failure is non-fatal — conversation continues.
      debugPrint('Interview audio playback failed: $err');
    } finally {
      _playing = false;
      if (file != null && file.existsSync()) file.deleteSync();
    }
  }

  /// Clear buffer without playing (e.g., on interruption).
  void clearBuffer() {
    if (_pcmBuffer.isNotEmpty) {
      debugPrint('PcmAudioPlayer.clearBuffer dropping ${_pcmBuffer.length} bytes');
    }
    _pcmBuffer.clear();
  }

  Future<void> dispose() async {
    _disposed = true;
    _pcmBuffer.clear();
    await _player.dispose();
  }

  @visibleForTesting
  static int? sampleRateFromElevenLabsFormat(String? format) {
    if (format == null) return null;
    final normalized = format.trim().toLowerCase();
    if (!normalized.startsWith('pcm_')) return null;
    final parsed = int.tryParse(normalized.substring(4));
    if (parsed == null || parsed <= 0) return null;
    return parsed;
  }

  @visibleForTesting
  static Uint8List wavBytesForTesting(
    Uint8List pcmData, {
    int sampleRate = _defaultSampleRate,
  }) {
    final dataSize = pcmData.length;
    final chunkSize = 36 + dataSize;
    final byteRate = sampleRate * _channels * (_bitsPerSample ~/ 8);
    final blockAlign = _channels * (_bitsPerSample ~/ 8);

    final header = ByteData(44);
    // RIFF chunk
    header.setUint8(0, 0x52); // R
    header.setUint8(1, 0x49); // I
    header.setUint8(2, 0x46); // F
    header.setUint8(3, 0x46); // F
    header.setUint32(4, chunkSize, Endian.little);
    header.setUint8(8, 0x57); // W
    header.setUint8(9, 0x41); // A
    header.setUint8(10, 0x56); // V
    header.setUint8(11, 0x45); // E
    // fmt chunk
    header.setUint8(12, 0x66); // f
    header.setUint8(13, 0x6D); // m
    header.setUint8(14, 0x74); // t
    header.setUint8(15, 0x20); // space
    header.setUint32(16, 16, Endian.little); // subchunk1 size
    header.setUint16(20, 1, Endian.little); // PCM format
    header.setUint16(22, _channels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, blockAlign, Endian.little);
    header.setUint16(34, _bitsPerSample, Endian.little);
    // data chunk
    header.setUint8(36, 0x64); // d
    header.setUint8(37, 0x61); // a
    header.setUint8(38, 0x74); // t
    header.setUint8(39, 0x61); // a
    header.setUint32(40, dataSize, Endian.little);

    final result = Uint8List(44 + dataSize);
    result.setAll(0, header.buffer.asUint8List());
    result.setAll(44, pcmData);
    return result;
  }
}
