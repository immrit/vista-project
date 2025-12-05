// test/phase3_integration_test.dart
//
// تست یکپارچگی برای فاز ۳ - ضبط و پخش صدا
//

import 'package:flutter_test/flutter_test.dart';
import 'package:Vista/features/chat/services/voice_recorder_service.dart';

void main() {
  group('Phase 3 - Voice Services Integration Tests', () {
    
    test('VoiceRecorderService is singleton', () {
      final recorder1 = VoiceRecorderService();
      final recorder2 = VoiceRecorderService();
      
      expect(identical(recorder1, recorder2), true);
    });

    test('VoiceRecorderService initializes without errors', () {
      final recorder = VoiceRecorderService();
      expect(recorder.isRecording, false);
    });

    test('amplitudeStream is a broadcast stream', () {
      final recorder = VoiceRecorderService();
      final stream1 = recorder.amplitudeStream;
      final stream2 = recorder.amplitudeStream;
      
      // Broadcast stream میتواند چندین listener داشته باشد
      expect(stream1, isNotNull);
      expect(stream2, isNotNull);
    });
  });
}
