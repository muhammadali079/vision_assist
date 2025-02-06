import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:camera/camera.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:testing/state_management/bloc/camera_bloc.dart';
import 'package:testing/state_management/events/camera_event.dart';
import 'package:testing/state_management/states/camera_state.dart';
import 'package:permission_handler/permission_handler.dart';

import '../main.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver {
  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _isSpeechInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // ✅ Observe app lifecycle
    _speech = stt.SpeechToText();
    _initializeSpeechRecognition();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // ✅ Clean up observer
    _speech.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // ✅ Restart listening when returning from OCR screen
      print("App resumed, restarting speech listening...");
      _isListening = false; // Reset listening state
      _startListening();
    } else if (state == AppLifecycleState.paused) {
      print("App paused!");
      // Stop listening when app goes to background
      _speech.stop();
      setState(() {
        _isListening = false;
      });
    }
  }

  // @override
  // void didChangeDependencies() {
  //   super.didChangeDependencies();
  //   if (!_isSpeechInitialized) {
  //     _initializeSpeechRecognition();
  //   }
  // }

  // ✅ Initialize speech recognition
  Future<void> _initializeSpeechRecognition() async {
    print("\n\n\n _initializeSpeechRecognition\n\n");

     PermissionStatus status = await Permission.microphone.status;
  if (!status.isGranted) {
    print("Microphone permission is not granted.");
    await Permission.microphone.request();
    if (await Permission.microphone.isDenied) {
      print("Microphone permission denied after request.");
      return;
    }
  }else{
    print("Microphone permission is granted."); 
  }

    bool available = await _speech.initialize(
      onStatus: (status) {
        print("Speech status: $status");
      },
      onError: (error) {
        print("Speech error: $error");
        _handleSpeechError(error);
      },
    );

    if (available) {
      setState(() {
        _isSpeechInitialized = true;
      });
      print("Speech recognition initialization Successfully");
    //   _isListening = true;
      _startListening(); // ✅ Start listening automatically
    } else {
      print("Speech recognition initialization failed");
    }
  }

  // ✅ Start listening for the word "capture"
void _startListening() async{
  print("Starting to listen...");

  if (_speech.isListening) {
    print("Already listening, not starting again.");
  } else {
    print("Starting the listening process now...");
    try {
      bool isInitialized = await _speech.initialize(
        onStatus: (status) {
          print("Speech status: $status");
        },
        onError: (error) {
          print("Speech error: $error");
        },
      );
     if (isInitialized) {
        print("Speech recognition initialization successfully completed.");

        // Start listening
        _speech.listen(
          onResult: (result) {
            print("Speech result: ${result.recognizedWords}");
            if (result.recognizedWords.toLowerCase().contains("capture")) {
              print("Capture command detected!");
              // Trigger the capture action here
            }
          },
          onSoundLevelChange: (level) {
            print("Sound level: $level");
          },
          listenFor: Duration(seconds: 30),
          partialResults: true,
          localeId: "en_US",
          onDevice: true, // Try switching this to false if issues persist
        );
      } else {
        print("Failed to initialize speech recognition.");
      }
    } catch (e) {
      print("Error during speech recognition initialization: $e");
    }
  }
}


  // ✅ Handle speech errors and retry listening
  void _handleSpeechError(SpeechRecognitionError error) {
    print("Speech error!!: ${error.errorMsg}");
    setState(() {
      _isListening = false; // Reset listening state
    });

    Future.delayed(const Duration(seconds: 1), () {
      if (!_isListening) {
        _startListening(); // Retry listening after a delay
      }
    });
  }

  // ✅ Capture image and go to OCR screen
  void _triggerCapture() {
    if (_speech.isListening) {
      _speech.stop(); // Stop recognition before processing
    }
    context.read<CaptureBloc>().add(CaptureThroughSpeak(context: context));
  }

  // ✅ Logout function
  Future<void> _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('isLoggedIn');
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AuthWrapper()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
  //  final captureBloc = context.read<CaptureBloc>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Document Scanner'),
        backgroundColor: Colors.deepPurple.shade800,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: BlocBuilder<CaptureBloc, CaptureState>(builder: (context, state) {
        final cameraBloc = context.read<CaptureBloc>();
        if (!cameraBloc.cameraService.controller.value.isInitialized) {
          return const Center(child: CircularProgressIndicator());
        }
        return CameraPreview(cameraBloc.cameraService.controller);
      }),
    );
  }
}
