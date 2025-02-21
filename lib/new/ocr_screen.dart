import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:audioplayers/audioplayers.dart';
import 'package:testing/new/camera_screen.dart';
import 'dart:convert';

import 'package:testing/new/signin_screen.dart';

class OcrScreen extends StatefulWidget {
  final String imagePath;
  const OcrScreen({super.key, required this.imagePath});

  @override
  _OcrScreenState createState() => _OcrScreenState();
}

class _OcrScreenState extends State<OcrScreen> {
  final FlutterTts _flutterTts = FlutterTts();
  final stt.SpeechToText _speech = stt.SpeechToText();
  final AudioPlayer _audioPlayer = AudioPlayer();
  String _extractedText = "Processing...";
  bool _isListening = false;
  bool _isOCRScreen = true;
  final String openAiApiKey =
      "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"; // Replace with actual API Key

  @override
  void initState() {
    super.initState();
    _extractText();
    _isOCRScreen = true;
  }

  Future<void> _extractText() async {
    try {
      final textRecognizer =
          TextRecognizer(script: TextRecognitionScript.latin);
      final inputImage = InputImage.fromFilePath(widget.imagePath);
      final recognizedText = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      String extracted = recognizedText.text.isNotEmpty
          ? recognizedText.text
          : "No readable text found.";
      setState(() => _extractedText = extracted);
      print("Extracted text: $extracted");

      await _speakWithOpenAI(extracted);
    } catch (e) {
      await _flutterTts.speak("Error while extracting text.");
      Future.delayed(const Duration(seconds: 2), _promptTTSUser);
    }
  }

  Future<void> _speakWithOpenAI(String text) async {
    try {
      final response = await http.post(
        Uri.parse("https://api.openai.com/v1/audio/speech"),
        headers: {
          "Authorization": "Bearer $openAiApiKey",
          "Content-Type": "application/json"
        },
        body: jsonEncode({"model": "tts-1", "voice": "alloy", "input": text}),
      );

      if (response.statusCode == 200) {
        final directory = await getTemporaryDirectory();
        final filePath = "${directory.path}/speech.mp3";
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);

        final uriPath = Uri.file(filePath).toString();
        await _audioPlayer.stop();
        await _audioPlayer.setSourceUrl(uriPath);
        await _audioPlayer.resume();
        await _audioPlayer.onPlayerComplete.first;
        Future.delayed(const Duration(seconds: 2), _promptTTSUser);
      } else {
        print("OpenAI TTS Error: ${response.body}");
      }
    } catch (e) {
      print("Error in OpenAI TTS: $e");
    }
  }

  Future<void> _speakWithFlutterTTS(String text) async {
    await _flutterTts.speak(text);
    await _flutterTts.awaitSpeakCompletion(true);
  }

  void _promptTTSUser() {
    _speakWithFlutterTTS(
        "Say capture to go back to camera again or exit to close app.");
    _startListeningForNewCommand();
  }

  void _startListeningForNewCommand() async {
    if (_isListening) return;
    setState(() => _isListening = true);

    bool available = await _speech.initialize();
    if (available) {
      _speech.listen(
        onResult: (result) {
          if (result.recognizedWords.isNotEmpty) {
            String command = result.recognizedWords.toLowerCase().trim();
            print("User said: $command");

            if (command.contains("retry") || command.contains("capture")) {
              _retry();
              return;
            } else if (command.contains("exit") || command.contains("close")) {
              _exitApp();
              return;
            } else if (command.contains("log out") ||
                command.contains("logout") ||
                command.contains("signout") ||
                command.contains("sign out")) {
              _logOut();
              return;
            }
          }
        },
      );
      _speech.statusListener = (status) {
        print("Speech recognition status: $status");

        if (status == "notListening" && _isOCRScreen) {
          print("Paused. Restarting listening...");
          _stopListening();

          if (!_isListening) {
            print("Restarting...");
            _startListeningForNewCommand();
          }
        }
      };
    }
  }

  void _logOut() async {
    _isOCRScreen = false;
    _speech.stop();

    // Clear the stored preferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    // Speak and navigate to SignInScreen
    _speakWithFlutterTTS("Logging out...");
    Future.delayed(const Duration(seconds: 2), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const SignInScreen()),
      );
    });
  }

  void _stopListening() {
    _speech.stop();
    setState(() => _isListening = false);
  }

  void _retry() {
    _isOCRScreen = false;
    _speech.stop();
    _speakWithFlutterTTS("Returning to camera...");
    Future.delayed(const Duration(seconds: 2), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const CameraScreen()),
      );
    });
  }

  void _exitApp() {
    _isOCRScreen = false;
    _speech.stop();
    _speakWithFlutterTTS("Closing app...");
    Future.delayed(const Duration(seconds: 2), () {
      SystemNavigator.pop();
    });
  }

  @override
  void dispose() {
    _speech.stop();
    _audioPlayer.stop();
    _audioPlayer.dispose();
    _isOCRScreen = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("OCR Result")),
      body: Column(
        children: [
          Expanded(child: Image.file(File(widget.imagePath))),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: Text(
                  _extractedText,
                  style: const TextStyle(fontSize: 18),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            "Say 'capture' to go back to camera again or 'exit' to close.",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
