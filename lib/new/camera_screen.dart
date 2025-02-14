import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:testing/new/ocr_screen.dart';
import 'dart:math' as math;

import 'package:testing/new/signin_screen.dart';

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
  bool isCameraScreen = true;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    //isCameraScreen = true;
    _flutterTts.speak(
        "Say Capture to take a picture, Log out to sign out of your account, or Exit to close the app.");
    _flutterTts.awaitSpeakCompletion(true);
  }

  Future<void> _initializeCamera() async {
    _cameras = await availableCameras();
    _controller = CameraController(_cameras[0], ResolutionPreset.max);
    await _controller.initialize();
    await _controller.setZoomLevel(1.0);

    if (!mounted) return;
    setState(() => _cameraInitialized = true);

    _initializeSpeech();
  }

  Future<void> _initializeSpeech() async {
    bool available = await _speech.initialize(
      onStatus: (status) {
        print("Speech status: $status");
      },
      onError: (error) {
        print("Speech error: $error");
      },
    );
    if (available) {
      _promptUser();
    } else {
      _readMessage("Speech recognition is not available.");
    }
  }

  void _promptUser() async {
    if (_isListening) return;
    _startListening();
  }

  Future<void> _exitApp() async {
    _speech.stop();
    await _flutterTts.speak("Closing app...");
    await _flutterTts.awaitSpeakCompletion(true);
    Future.delayed(const Duration(seconds: 1), () {
      SystemNavigator.pop();
    });
  }

  void _startListening() async {
    if (_isListening) return;
    // await _flutterTts
    //     .speak("Say capture to take a picture or exit to close the app.");
    // await _flutterTts.awaitSpeakCompletion(true);

    setState(() => _isListening = true);
    print("Listening for commands...");

    _speech.listen(
      onResult: (result) async {
        if (result.recognizedWords.isNotEmpty) {
          String command = result.recognizedWords.toLowerCase().trim();
          print("Recognized command: $command");

          if (command.contains("capture")) {
            _takePicture();
          } else if (command.contains("go out") ||
              command.contains("sign out") ||
              command.contains("log out") ||
              command.contains("logout")) {
            _logOut();
          } else if (command.contains("exit") || command.contains("close")) {
            _exitApp();
          } else {
            _readMessage(
                "Command not recognized. Please say capture or log out.");
          }
        }
      },
      listenFor: Duration(seconds: 30),
      pauseFor: Duration(seconds: 7),
    );
    _speech.statusListener = (status) {
      print("Speech recognition status: $status");

      if (status == "notListening" && isCameraScreen) {
        print("Paused. Restarting listening...");

        Future.delayed(Duration(seconds: 7), () {
          print("Restarting after pause...");
          _stopListening();
          Future.delayed(Duration(seconds: 1), () {
            _startListening();
          });
        });
      }
    };
  }

  void _stopListening() {
    _speech.stop();
    setState(() => _isListening = false);
  }

  Future<void> _takePicture() async {
    isCameraScreen = false;
    _stopListening();

    await _flutterTts.stop();
    await _flutterTts.speak("Capturing image...");
    await _flutterTts.awaitSpeakCompletion(true);

    try {
      final XFile image = await _controller.takePicture();
      _readMessage("Picture taken successfully.");
      await _flutterTts.awaitSpeakCompletion(true);
      await _flutterTts.stop();
      if (_speech.isListening) {
        _speech.stop();
      }

      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => OcrScreen(imagePath: image.path)),
      );
    } catch (e) {
      _readMessage("Failed to capture image.");
    }
  }

  void _logOut() {
    _stopListening();
    _readMessage("Logging out...");
    Future.delayed(const Duration(seconds: 2), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const SignInScreen()),
      );
    });
  }

  void _readMessage(String message) async {
    await _flutterTts.speak(message);
    await _flutterTts.awaitSpeakCompletion(true);
  }

  @override
  void dispose() {
    isCameraScreen = false;
    _speech.stop();
    _speech.statusListener = null;
    _flutterTts.stop();
    _controller.dispose();
    super.dispose();
  }

  double getAspectRatio() {
    if (!_controller.value.isInitialized ||
        _controller.value.previewSize == null) {
      return 1.0;
    }
    return _controller.value.previewSize!.height /
        _controller.value.previewSize!.width;
  }

  Widget buildCameraPreview() {
    if (!_controller.value.isInitialized) return Container();

    double previewAspectRatio = _controller.value.previewSize!.width /
        _controller.value.previewSize!.height;
    double screenAspectRatio =
        MediaQuery.of(context).size.width / MediaQuery.of(context).size.height;

    double scale = previewAspectRatio / screenAspectRatio;

    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..rotateZ(getCorrectedRotation() * (math.pi / 180)),
      child: Transform.scale(
        scale: scale > 1 ? scale : 1 / scale,
        child: AspectRatio(
          aspectRatio: previewAspectRatio,
          child: CameraPreview(_controller),
        ),
      ),
    );
  }

  double getCorrectedRotation() {
    if (!_controller.value.isInitialized) return 0;

    final CameraDescription description = _controller.description;
    if (description.lensDirection == CameraLensDirection.front) {
      return (360 - description.sensorOrientation) % 360;
    } else {
      return description.sensorOrientation.toDouble();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _cameraInitialized
          ? Stack(
              children: [
                Center(child: buildCameraPreview()),
                Positioned(
                  bottom: 50,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Text(
                      "Say 'Capture' to take a picture, 'Log out' to sign out of your account, or 'Exit' to close the app.",
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
