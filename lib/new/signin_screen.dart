import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:testing/camera_screen.dart';
import 'package:testing/new/signup_screen.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  _SignInScreenState createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen>
    with WidgetsBindingObserver {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final stt.SpeechToText _speech = stt.SpeechToText();
  FlutterTts flutterTts = FlutterTts();

  bool switchingscreen = false;
  bool _isListening = false;
  bool _isProcessing = false;
  int _currentFieldIndex = 0;

  final List<Map<String, String>> _formFields = [
    {'label': 'Email Address', 'value': ''},
    {'label': 'Password', 'value': ''},
  ];

  final List<TextEditingController> _controllers = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeSpeech();
    _initializeControllers();
    _promptUser();
  }

  void _initializeControllers() {
    _controllers.addAll(_formFields
        .map((field) => TextEditingController(text: field['value'])));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _speech.stop();
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _speech.stop();
      _isListening = false;
    } else if (state == AppLifecycleState.resumed) {
      _promptUser();
    }
  }

  void _initializeSpeech() async {
    bool available = await _speech.initialize();
    if (!available) {
      _readMessage("Speech recognition is not available on this device.");
    }
  }

  void _promptUser() {
    if (_currentFieldIndex < _formFields.length && !_isListening) {
      Future.delayed(const Duration(microseconds: 200), () {
        _startListening(_formFields[_currentFieldIndex]['label']!);
      });
    }
  }

  void _startListening(String fieldLabel) async {
    if (_isListening || _isProcessing) return;

    setState(() => _isListening = true);

    await flutterTts.awaitSpeakCompletion(true);
    await flutterTts.speak("Please say your $fieldLabel.");
    await flutterTts.awaitSpeakCompletion(true);

    bool speechDetected = false;

    Future.delayed(const Duration(seconds: 10), () {
      if (!speechDetected && _isListening) {
        flutterTts.speak("I didn't hear anything. Please try again.");
        _stopListening();
        Future.delayed(
            const Duration(seconds: 5), () => _startListening(fieldLabel));
      }
    });

    _speech.listen(onResult: (result) async {
      if (result.recognizedWords.isNotEmpty) {
        speechDetected = true;
        String updatedWords = result.recognizedWords.toLowerCase().trim();

        // Map<String, String> replacements = {
        //   " at the great ": "@",
        //   " the great ": "@",
        //   "at the great ": "@",
        //   " at the great": "@",
        //   "singing": "sign in",
        // };
        Map<RegExp, String> replacements = {
          RegExp(r"\b(at )?the great\b", caseSensitive: false): "@",
          RegExp(r"\bsinging\b", caseSensitive: false): "sign in",
        };
        // replacements.forEach((oldWord, newWord) {
        //   updatedWords = updatedWords.replaceAll(oldWord, newWord);
        // });
        replacements.forEach((oldWord, newWord) {
          updatedWords =
              updatedWords.replaceAllMapped(oldWord, (match) => newWord);
        });
        updatedWords = updatedWords.replaceAll(RegExp(r'\s*@\s*'), '@');
        updatedWords = updatedWords.replaceAll(
            RegExp(r'\bGmail\b', caseSensitive: true), 'gmail');
        updatedWords = updatedWords.replaceAll(RegExp(r'\s+'), ' ').trim();
        print("Updated Words: $updatedWords");

        if (updatedWords.contains("sign up") ||
            updatedWords.contains("switch") ||
            updatedWords.contains("toggle")) {
          switchingscreen = true;
          _stopListening();
          await flutterTts.speak("Switching to sign in screen");
          await flutterTts.awaitSpeakCompletion(true);

          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SignUpScreen(),
              ),
            );
          }
        } else {
          setState(() {
            _formFields[_currentFieldIndex]['value'] = updatedWords;
            _controllers[_currentFieldIndex].text = updatedWords;
          });

          _stopListening();
          // await flutterTts.awaitSpeakCompletion(true);
          // await flutterTts.speak("You said $updatedWords.");
          // await flutterTts.awaitSpeakCompletion(true);

          if (!switchingscreen &&
              updatedWords.isNotEmpty &&
              _currentFieldIndex == _formFields.length - 1 &&
              (_formFields[_currentFieldIndex]['value']?.isNotEmpty ?? false)) {
            await flutterTts.speak("All fields are filled.");
            await flutterTts.awaitSpeakCompletion(true);
            await _signIn();
          } else if (!switchingscreen &&
              updatedWords.isNotEmpty &&
              (_formFields[_currentFieldIndex]['value']?.isNotEmpty ?? false)) {
            print(_currentFieldIndex);
            print(_formFields[_currentFieldIndex]['label']);
            print(_formFields[_currentFieldIndex]['value']);
            await Future.delayed(const Duration(seconds: 3));
            _goToNextField();
          }
        }
      }
    });
  }

  void _stopListening() {
    _speech.stop();
    setState(() => _isListening = false);
  }

  void _goToNextField() async {
    _stopListening();
    print("current index $_currentFieldIndex");
    setState(() {
      _isProcessing = true;
      if (_currentFieldIndex < _formFields.length - 1 &&
          (_formFields[_currentFieldIndex]['value']?.isNotEmpty ?? false)) {
        _currentFieldIndex++;
      }
    });
    print("new index $_currentFieldIndex");
    await Future.delayed(const Duration(seconds: 1));
    setState(() => _isProcessing = false);
    _promptUser();
  }

  void _readMessage(String message) async {
    await flutterTts.speak(message);
  }

  Future<void> _signIn() async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: _formFields[0]['value']!,
        password: _formFields[1]['value']!,
      );
      _readMessage("Sign in successful. Welcome back!");
      await flutterTts.awaitSpeakCompletion(true);
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const CameraScreen()));
    } catch (e) {
      await flutterTts.speak("Error signing in. Please try again");
      await flutterTts.awaitSpeakCompletion(true);
      Future.delayed(const Duration(seconds: 2), () {
        _resetForm();
      });
    }
  }

  void _resetForm() {
    setState(() {
      for (var field in _formFields) {
        field['value'] = '';
      }
      for (var controller in _controllers) {
        controller.clear();
      }
      _currentFieldIndex = 0;
    });

    Future.delayed(const Duration(seconds: 2), () {
      _promptUser();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Sign In')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Current Field: ${_formFields[_currentFieldIndex]['label']}",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _controllers[_currentFieldIndex],
              decoration: InputDecoration(
                labelText: _formFields[_currentFieldIndex]['label'],
                hintText:
                    'Enter your ${_formFields[_currentFieldIndex]['label']}',
              ),
              enabled: false,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
