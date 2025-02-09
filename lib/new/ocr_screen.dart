import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'dart:io';
import 'camera_screen.dart';

class OcrScreen extends StatefulWidget {
  final String imagePath;
  const OcrScreen({super.key, required this.imagePath});

  @override
  _OcrScreenState createState() => _OcrScreenState();
}

class _OcrScreenState extends State<OcrScreen> {
  final FlutterTts _flutterTts = FlutterTts();
  final stt.SpeechToText _speech = stt.SpeechToText();
  String _extractedText = "Processing...";
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _extractText();
  }

  Future<void> _extractText() async {
    try {
      final textRecognizer = TextRecognizer();
      final inputImage = InputImage.fromFilePath(widget.imagePath);
      final recognizedText = await textRecognizer.processImage(inputImage);
      String extracted = recognizedText.text.isNotEmpty
          ? recognizedText.text
          : "No readable text found.";

      setState(() => _extractedText = extracted);
      print("Extracted text: $extracted");
      await _flutterTts.speak(extracted);
      await _flutterTts.awaitSpeakCompletion(true);
      Future.delayed(const Duration(seconds: 2), () => _promptUser());
    } catch (e) {
      await _flutterTts.speak("error while extracting text");
    }
  }

  void _promptUser() {
    _flutterTts.speak(
        "Say 'retry' to take another picture or 'exit' to close the app.");
    _startListening();
  }

  void _startListening() async {
    if (_isListening) return;
    setState(() => _isListening = true);

    _speech.listen(onResult: (result) {
      if (result.recognizedWords.isNotEmpty) {
        String command = result.recognizedWords.toLowerCase().trim();
        if (command.contains("retry")) {
          _retry();
        } else if (command.contains("exit")) {
          _exitApp();
        }
      }
    });

    Future.delayed(const Duration(seconds: 10), () {
      if (_isListening) {
        _flutterTts.speak("Say 'retry' or 'exit'.");
        _speech.stop();
        Future.delayed(const Duration(seconds: 5), () => _startListening());
      }
    });
  }

  void _retry() {
    _speech.stop();
    _flutterTts.speak("Returning to camera...");
    Future.delayed(const Duration(seconds: 2), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const CameraScreen()),
      );
    });
  }

  void _exitApp() {
    _speech.stop();
    _flutterTts.speak("Closing app...");
    Future.delayed(const Duration(seconds: 2), () => Navigator.pop(context));
  }

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("OCR Result")),
      body: Column(
        children: [
          Expanded(child: Image.file(File(widget.imagePath))),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              _extractedText,
              style: const TextStyle(fontSize: 18),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            "Say 'retry' to capture again or 'exit' to close.",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
