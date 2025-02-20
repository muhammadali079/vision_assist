import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

class _CameraScreenState extends State<CameraScreen>
    with SingleTickerProviderStateMixin {
  late CameraController _controller;
  late List<CameraDescription> _cameras;
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  bool _isListening = false;
  bool _cameraInitialized = false;
  bool isCameraScreen = true;
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;
  bool _isTouching = false;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _glowAnimation = Tween<double>(begin: 0, end: 1).animate(_glowController);
    _initializeCamera();
    //isCameraScreen = true;
    _flutterTts.speak(
        "Touch and hold anywhere on screen for half a second to capture image. Say Log out to sign out of your account, or Exit to close the app.");
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

  void _logOut() async {
    // Stop listening to speech and clear flags
    _stopListening();

    // Clear shared preferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    // Speak logout message and ensure it completes before navigation
    await _flutterTts.speak("Logging out...");
    await _flutterTts.awaitSpeakCompletion(true); // Ensure TTS completes

    // Navigate to SignInScreen
    if (context.mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const SignInScreen()),
      );
    }
  }

  void _readMessage(String message) async {
    await _flutterTts.speak(message);
    await _flutterTts.awaitSpeakCompletion(true);
  }

  @override
  void dispose() {
    _glowController.dispose();
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

    // Get the screen size
    final size = MediaQuery.of(context).size;

    // Calculate preview sizes and ratios
    var scale = size.aspectRatio * _controller.value.aspectRatio;

    // Check if we need to scale width or height
    if (scale < 1) scale = 1 / scale;

    // Handle platform-specific rotation
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    final rotationDegrees = isIOS ? 0.0 : getCorrectedRotation();

    return Transform.scale(
      scale: scale,
      child: Center(
        child: Transform.rotate(
          angle: rotationDegrees * (math.pi / 180),
          child: CameraPreview(_controller),
        ),
      ),
    );
  }

  double getCorrectedRotation() {
    if (!_controller.value.isInitialized) return 0;

    final description = _controller.description;
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;

    // iOS handles rotation differently, so we return 0
    if (isIOS) return 0;

    if (description.lensDirection == CameraLensDirection.front) {
      return (360 - description.sensorOrientation) % 360;
    } else {
      return description.sensorOrientation.toDouble();
    }
  }

  void _handleTapDown(TapDownDetails details) {
    setState(() => _isTouching = true);
    _glowController.forward();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_isTouching) {
        _takePicture();
      }
    });
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() => _isTouching = false);
    _glowController.reverse();
  }

  void _handleTapCancel() {
    setState(() => _isTouching = false);
    _glowController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _cameraInitialized
          ? SafeArea(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  GestureDetector(
                    onTapDown: _handleTapDown,
                    onTapUp: _handleTapUp,
                    onTapCancel: _handleTapCancel,
                    child: AnimatedBuilder(
                      animation: _glowAnimation,
                      builder: (context, child) {
                        return Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.green
                                  .withOpacity(_glowAnimation.value * 0.5),
                              width: 10 * _glowAnimation.value,
                            ),
                          ),
                          child: buildCameraPreview(),
                        );
                      },
                    ),
                  ),
                  Positioned(
                    bottom: 50,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Text(
                        "Touch and hold anywhere on screen for half a second to capture image.\nSay 'Log out' to sign out of your account, or 'Exit' to close the app.",
                        textAlign: TextAlign.center,
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
              ),
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }
}
