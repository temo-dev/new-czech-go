// SimliSessionManager uses flutter_webrtc (native plugin) which requires
// a real device. Instantiation is NOT possible in unit tests.
// Verification strategy:
//   1. flutter analyze — verifies the class compiles correctly
//   2. flutter build ios — verifies native deps resolve
//   3. Manual device test — verifies start()/sendAudio()/dispose() behavior
//
// This file exists as a compile-check and documents the manual test plan.

import 'package:flutter_test/flutter_test.dart';
// Import only the constants file — simli_session_manager.dart imports
// flutter_webrtc (native plugin) which is unavailable in VM unit tests.
import 'package:flutter_app/features/interview/services/simli_config.dart';

void main() {
  test('SimliConfig constants exist (compile check)', () {
    // Just verify the constants are accessible — no native code needed.
    expect(SimliConfig.apiKey, isA<String>());
    expect(SimliConfig.faceId, isA<String>());
  });

  // Manual checklist (Sprint 0 — validate on iPhone before merging):
  // [ ] SimliSessionManager(apiKey: k, faceId: f) creates without throw
  // [ ] start() connects to Simli WebRTC within 3s
  // [ ] sendAudio(pcm16Chunk) triggers lip-sync animation visible on screen
  // [ ] dispose() cleanly closes the connection
}
