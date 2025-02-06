// import 'dart:async';
// import 'package:camera/camera.dart';
// import 'package:flutter/material.dart';
// import 'package:speech_to_text/speech_to_text.dart';
// import 'ocr_screen.dart';

// class CameraScreen extends StatefulWidget {
//   const CameraScreen({super.key});

//   @override
//   State<CameraScreen> createState() => _CameraScreenState();
// }

// class _CameraScreenState extends State<CameraScreen> {
//   late CameraController _controller;
//   late Future<void> _initializeController;
//   final SpeechToText _speech = SpeechToText();
//   bool _isListening = false;
//   bool _isProcessing = false;

//   @override
//   void initState() {
//     super.initState();
//     _initializeCamera();
//     _initializeSpeech();
//   }

//   Future<void> _initializeCamera() async {
//     final cameras = await availableCameras();
//     _controller = CameraController(cameras[0], ResolutionPreset.medium);
//     _initializeController = _controller.initialize();
//     setState(() {});
//   }

//   Future<void> _initializeSpeech() async {
//     await _speech.initialize();
//   }

//   Future<void> _startListening() async {
//     if (!_isListening && !_isProcessing) {
//       setState(() => _isListening = true);
//       await _speech.listen(
//         onResult: (result) => _handleSpeech(result.recognizedWords),
//         listenFor: const Duration(seconds: 5),
//         pauseFor: const Duration(seconds: 2),
//       );
//     }
//   }

//   void _handleSpeech(String words) async {
//     final command = words.toLowerCase().trim();
//     if (command.contains('capture') && !_isProcessing) {
//       setState(() => _isProcessing = true);
//       await _takePicture();
//       setState(() => _isProcessing = false);
//     }
//     setState(() => _isListening = false);
//   }

//   Future<void> _takePicture() async {
//     try {
//       await _initializeController;
//       final image = await _controller.takePicture();
//       if (mounted) {
//         Navigator.push(
//           context,
//           MaterialPageRoute(
//             builder: (context) => OCRScreen(imagePath: image.path),
//           ),
//         );
//       }
//     } catch (e) {
//       debugPrint("Error taking picture: $e");
//     }
//   }

//   @override
//   void dispose() {
//     _controller.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Document Scanner'),
//         backgroundColor: Colors.deepPurple.shade800,
//       ),
//       body: FutureBuilder<void>(
//         future: _initializeController,
//         builder: (context, snapshot) {
//           if (snapshot.connectionState == ConnectionState.done) {
//             return CameraPreview(_controller);
//           }
//           return const Center(child: CircularProgressIndicator());
//         },
//       ),
//       floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
//       floatingActionButton: Column(
//         mainAxisAlignment: MainAxisAlignment.end,
//         children: [
//           _buildVoiceIndicator(),
//           const SizedBox(height: 20),
//           _buildCaptureButton(),
//         ],
//       ),
//     );
//   }

//   Widget _buildVoiceIndicator() {
//     return AnimatedOpacity(
//       opacity: _isListening ? 1.0 : 0.0,
//       duration: const Duration(milliseconds: 200),
//       child: const Column(
//         children: [
//           Icon(Icons.record_voice_over, color: Colors.white, size: 40),
//           Text(
//             "Say 'CAPTURE' to take photo",
//             style: TextStyle(color: Colors.white, fontSize: 16),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildCaptureButton() {
//     return FloatingActionButton(
//       backgroundColor: _isListening ? Colors.amber : Colors.deepPurple,
//       onPressed: () async {
//         if (!_isProcessing) {
//           await _startListening();
//         }
//       },
//       child: Icon(
//         _isProcessing ? Icons.camera : Icons.mic,
//         color: Colors.white,
//         size: 32,
//       ),
//     );
//   }
// }