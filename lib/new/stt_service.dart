// import 'package:speech_to_text/speech_to_text.dart' as stt;
// import 'package:flutter_tts/flutter_tts.dart';

// class SpeechService {
//   final stt.SpeechToText _speech = stt.SpeechToText();
//   final FlutterTts _flutterTts = FlutterTts();
//   bool _isListening = false;

//   Future<bool> initializeSpeech() async {
//     return await _speech.initialize();
//   }

//   void startListening(Function(String) onResult) {
//     if (_isListening) return;

//     _isListening = true;

//     _speech.listen(
//       onResult: (result) {
//         if (result.recognizedWords.isNotEmpty) {
//           String correctedText = result.recognizedWords
//               .replaceAll(" at the great ", "@")
//               .replaceAll(" dot com ", ".com")
//               .replaceAll(" mail ", "male");

//           onResult(correctedText);
//         }
//       },
//       listenFor: Duration(minutes: 5), // Continuous listening
//       pauseFor: Duration(seconds: 10), // Auto-pause after inactivity
//       partialResults: false, // Get final result
//     );

//     // Timeout check: If no speech detected within 10 seconds, stop listening
//     Future.delayed(Duration(seconds: 10), () {
//       if (_isListening) {
//         stopListening();
//       }
//     });
//   }

//   void stopListening() {
//     if (_isListening) {
//       _isListening = false;
//       _speech.stop();
//     }
//   }

//   Future<void> speak(String message, {Function()? onComplete}) async {
//     await _flutterTts.speak(message);
//     _flutterTts.setCompletionHandler(() {
//       if (onComplete != null) {
//         onComplete();
//       }
//     });
//   }
// }
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:audioplayers/audioplayers.dart';

class SpeechService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;  // Prevent starting listening multiple times
  bool _isPlaying = false;    // Prevent overlapping speech playback
  final AudioPlayer _audioPlayer = AudioPlayer();
  final String _apiKey =
      "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";

  Future<bool> initializeSpeech() async {
    return await _speech.initialize();
  }

  void startListening(Function(String) onResult) async {
    if (_isListening || _isPlaying) return;  // Prevent concurrent listening or playback

    bool available = await _speech.initialize(
      onError: (error) => print("Speech recognition error: $error"),
      onStatus: (status) => print("Speech recognition status: $status"),
    );
    if (!available) {
      print("Speech recognition is not available!");
      return;
    }

    _isListening = true;  // Set listening flag
    print("Start listening");

    _speech.listen(
      onResult: (result) {
        print("Raw Recognized Words: ${result.recognizedWords}");
        if (result.recognizedWords.isNotEmpty) {
          String correctedText = result.recognizedWords
              .replaceAll(" at the great ", "@")
              .replaceAll(" dot com ", ".com")
              .replaceAll(" mail ", "male");
          onResult(correctedText);
        } else {
          print("Result not recognized");
          onResult(result.recognizedWords);
        }
      },
      listenFor: Duration(seconds: 10),
      pauseFor: Duration(seconds: 5),
    );
  }

  void stopListening() {
    _speech.stop();
    _isListening = false;  // Reset listening flag when stopping
  }

  Future<void> speak(String message, {Function()? onComplete}) async {
    if (_isPlaying) return;  // Prevent overlapping speech playback

    _isPlaying = true;  // Mark playback as active

    final url = Uri.parse("https://api.openai.com/v1/audio/speech");

    final response = await http.post(
      url,
      headers: {
        "Authorization": "Bearer $_apiKey",
        "Content-Type": "application/json"
      },
      body: jsonEncode({
        "model": "tts-1",
        "voice": "alloy", // Choose voice
        "input": message,
      }),
    );

    if (response.statusCode == 200) {
      final bytes = response.bodyBytes;
      if (onComplete != null) {
        _audioPlayer.onPlayerComplete.listen((_) {
          print("Speech playback completed.");
          _isPlaying = false;  // Reset playback flag after completion
          onComplete();
        });
      }
      await _audioPlayer.play(BytesSource(bytes));
    } else {
      print("OpenAI TTS Error: ${response.body}");
      _isPlaying = false;  // Reset playback flag on error
    }
  }

  // Retry logic for speech recognition after a delay
  void retryListening(Function(String) onResult) async {
    if (_isListening || _isPlaying) return;  // Ensure no concurrent operations
    await Future.delayed(Duration(seconds: 1));  // Add a delay before retrying
    startListening(onResult);  // Retry the listening process
  }
}
