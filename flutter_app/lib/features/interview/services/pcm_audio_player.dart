import 'dart:async';
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
  bool _disposed = false;
  int _sampleRate;
  double _volumeGain = 1.0;
  Future<void>? _flushFuture;

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

  void setVolumeGain(double gain) {
    _volumeGain = normalizeVolumeGain(gain);
  }

  /// Play and clear the current buffer. No-op if buffer is empty.
  ///
  /// Calls made while playback is already in progress wait for the same drain
  /// future instead of returning early. This lets the interview screen keep
  /// the mic locked until the examiner audio has actually finished playing.
  Future<void> flushAndPlay() async {
    if (_disposed) return;
    if (_flushFuture != null) {
      await _flushFuture;
      return;
    }
    if (_pcmBuffer.isEmpty) return;

    _flushFuture = _drainBuffer();
    try {
      await _flushFuture;
    } finally {
      _flushFuture = null;
    }
  }

  Future<void> _drainBuffer() async {
    while (_pcmBuffer.isNotEmpty && !_disposed) {
      final pendingBytes = _pcmBuffer.length;
      // V16: trace local audio playback so we can diagnose missed-audio reports.
      // Bytes / sample rate / channels gives effective duration in seconds.
      final approxSec =
          pendingBytes / (_sampleRate * _channels * (_bitsPerSample / 8));
      debugPrint(
        'PcmAudioPlayer.flushAndPlay sampleRate=$_sampleRate '
        'gain=${_volumeGain.toStringAsFixed(2)} '
        'bytes=$pendingBytes approxDurationSec=${approxSec.toStringAsFixed(2)}',
      );
      await _playCurrentBuffer();
    }
  }

  Future<void> _playCurrentBuffer() async {
    final data = Uint8List.fromList(_pcmBuffer);
    _pcmBuffer.clear();

    // Declare file outside try so finally can clean it up on any code path.
    File? file;
    try {
      final adjustedData = applyPcm16GainForTesting(data, _volumeGain);
      final wavBytes = wavBytesForTesting(
        adjustedData,
        sampleRate: _sampleRate,
      );
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
      if (file != null && file.existsSync()) file.deleteSync();
    }
  }

  /// Clear buffer without playing (e.g., on interruption).
  void clearBuffer() {
    if (_pcmBuffer.isNotEmpty) {
      debugPrint(
        'PcmAudioPlayer.clearBuffer dropping ${_pcmBuffer.length} bytes',
      );
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
  static double normalizeVolumeGain(double gain) {
    if (gain.isNaN || gain.isInfinite) return 1.0;
    return gain.clamp(0.0, 2.0).toDouble();
  }

  @visibleForTesting
  static Uint8List applyPcm16GainForTesting(Uint8List pcmData, double gain) {
    final normalizedGain = normalizeVolumeGain(gain);
    if (pcmData.isEmpty || normalizedGain == 1.0) {
      return Uint8List.fromList(pcmData);
    }

    final result = Uint8List.fromList(pcmData);
    final view = ByteData.sublistView(result);
    for (var offset = 0; offset + 1 < result.length; offset += 2) {
      final sample = view.getInt16(offset, Endian.little);
      final adjusted =
          (sample * normalizedGain).round().clamp(-32768, 32767).toInt();
      view.setInt16(offset, adjusted, Endian.little);
    }
    return result;
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
