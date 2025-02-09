import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class SpeechToTextService {
  late stt.SpeechToText _speech;
  bool _isInitialized = false;

  bool get isListening => _speech.isListening;
  bool get isInitialized => _isInitialized;

  Future<bool> initialize() async {
    if (_isInitialized) return true;
    _speech = stt.SpeechToText();
    bool available = await _speech.initialize(
      onStatus: (status) {
        print("Speech status: $status");
      },
      onError: (error) {
        print("Speech error: $error");
      },
    );
    if (available) {
      _isInitialized = true;
    }
    return available;
  }

  void startListening(Function(String) onResult) {
    if (_speech.isListening) {
      print("Already listening. Skipping start listening.");
      return; // Prevent starting listening if already listening
    }
    _speech.listen(
      onResult: (result) {
        print("Speech result: ${result.recognizedWords}");
        if (result.recognizedWords.toLowerCase().contains("capture")) {
          print("Capture command detected!");
          // Stop listening once "capture" is detected
          stopListening();
        }
      },
      onSoundLevelChange: (level) {
        print("Sound level: $level");
      },
      listenFor: Duration(seconds: 4),
      pauseFor: Duration(seconds: 2),
      partialResults: true,
      localeId: "en_US",
      onDevice: true,
    );
  }

  void stopListening() {
    _speech.stop();
  }

  void handleError(SpeechRecognitionError error) {
    print("Speech error!!: ${error.errorMsg}");
  }
}
