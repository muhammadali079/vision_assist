import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:testing/new/ocr_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController _controller;
  late List<CameraDescription> _cameras;
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  bool _isListening = false;
  bool _cameraInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    _cameras = await availableCameras();
    _controller = CameraController(_cameras[0], ResolutionPreset.max);
    await _controller.initialize();

    if (!mounted) return;
    setState(() => _cameraInitialized = true);
    
    _initializeSpeech();
  }

  Future<void> _initializeSpeech() async {
    bool available = await _speech.initialize();
    if (available) {
      _promptUser();
    } else {
      _readMessage("Speech recognition is not available.");
    }
  }

  void _promptUser() async {
    if (_isListening) return;
    
    await _flutterTts.speak("Say capture to take a picture or log out to exit.");
    await _flutterTts.awaitSpeakCompletion(true);

    _startListening();
  }

  void _startListening() async {
    if (_isListening) return;

    setState(() => _isListening = true);

    bool speechDetected = false;

    _speech.listen(onResult: (result) async {
      if (result.recognizedWords.isNotEmpty) {
        speechDetected = true;
        String command = result.recognizedWords.toLowerCase().trim();

        if (command.contains("capture")) {
          _takePicture();
        } else if (command.contains("log out")) {
          _logOut();
        } else {
          _readMessage("Command not recognized. Please say capture or log out.");
        }
      }
    });

    Future.delayed(const Duration(seconds: 10), () {
      if (!speechDetected && _isListening) {
        _stopListening();
        _readMessage("Say capture.");
        Future.delayed(const Duration(seconds: 5), _startListening);
      }
    });
  }

  void _stopListening() {
    _speech.stop();
    setState(() => _isListening = false);
  }

  Future<void> _takePicture() async {
    _stopListening();
    await _flutterTts.speak("Capturing image...");
    await _flutterTts.awaitSpeakCompletion(true);

    try {
      final XFile image = await _controller.takePicture();
      _readMessage("Picture taken successfully.");
      await _flutterTts.awaitSpeakCompletion(true);

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => OcrScreen(imagePath: image.path)),
      );
    } catch (e) {
      _readMessage("Failed to capture image.");
    }

    _promptUser();
  }

  void _logOut() {
    _stopListening();
    _readMessage("Logging out...");
    Navigator.pop(context);
  }

  void _readMessage(String message) async {
    await _flutterTts.speak(message);
    await _flutterTts.awaitSpeakCompletion(true);
  }

  @override
  void dispose() {
    _speech.stop();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _cameraInitialized
          ? Stack(
              fit: StackFit.expand,
              children: [
                CameraPreview(_controller),
                Positioned(
                  bottom: 50,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Text(
                      "Say 'capture' to take a picture or 'log out' to exit.",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        backgroundColor: Colors.black54,
                      ),
                    ),
                  ),
                ),
              ],
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }
}
