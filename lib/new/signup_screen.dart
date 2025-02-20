import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:testing/new/camera_screen.dart';
import 'package:testing/new/signin_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen>
    with WidgetsBindingObserver {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final stt.SpeechToText _speech = stt.SpeechToText();
  FlutterTts flutterTts = FlutterTts();

  bool switchingscreen = false;
  bool _isListening = false;
  final bool _isProcessing = false;
  int _currentFieldIndex = 0;
  bool isSpeechActive = false;
  String updatedWords = "";
  bool _isManualInput = false;

  final List<Map<String, String>> _formFields = [
    {'label': 'Email Address', 'value': ''},
    {'label': 'Password', 'value': ''},
    {'label': 'Phone Number', 'value': ''},
  ];

  final List<TextEditingController> _controllers = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkSignUpState(); // Add this line
    _initializeSpeech();
    _initializeControllers();
    _promptUser();
  }

//Add this new method below your existing methods
  void _checkSignUpState() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isSignedUp = prefs.getBool('isSignedUp') ?? false;

    if (isSignedUp) {
      // Navigate directly to the CameraScreen
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const CameraScreen()));
    }
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
      Future.delayed(const Duration(seconds: 1), () {
        _startListening(_formFields[_currentFieldIndex]['label']!);
      });
    }
  }

  void _startListening(String fieldLabel) async {
    if (_isListening) return;

    setState(() {
      _isListening = true;
      updatedWords = "";
    });
    isSpeechActive = true;

    _readMessage("Please say your $fieldLabel.");
    await flutterTts.awaitSpeakCompletion(true);

    bool hasSpoken = false;
    Timer? pauseTimer;

    _speech.listen(
      onResult: (result) {
        if (result.recognizedWords.isNotEmpty) {
          hasSpoken = true;
          updatedWords = result.recognizedWords.toLowerCase().trim();
          updatedWords = updatedWords.replaceAll(RegExp(r'\s*@\s*'), '@');
          updatedWords = updatedWords.replaceAll(
              RegExp(r'\bGmail\b', caseSensitive: true), 'gmail');
          updatedWords = updatedWords.replaceAll(RegExp(r'\s+'), ' ').trim();

          print("Updated Words: $updatedWords");
          if (updatedWords.contains("toggle") ||
              updatedWords.contains("switch") ||
              updatedWords.contains("sign in") ||
              updatedWords.contains("signin") ||
              updatedWords.contains("singin")) {
            print("Navigating to Sign in screen...");
            _readMessage("Switching to Sign in screen...");
            Future.delayed(const Duration(seconds: 1), () {
              Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (_) => const SignInScreen()));
            });

            return;
          } else if (updatedWords.contains("exit") ||
              updatedWords.contains("close")) {
            print("Closing the app...");
            _readMessage("Closing the app...");
            Future.delayed(const Duration(seconds: 1), () {
              SystemNavigator.pop();
            });
            return;
          }

          setState(() {
            _formFields[_currentFieldIndex]['value'] = updatedWords;
            _controllers[_currentFieldIndex].text = updatedWords;
          });

          pauseTimer?.cancel();
        }
      },
      listenFor: const Duration(seconds: 20),
      pauseFor: const Duration(seconds: 10),
    );

    pauseTimer = Timer(const Duration(seconds: 10), () {
      if (_isListening && _formFields[_currentFieldIndex]['value']!.isEmpty) {
        print("PauseFor timeout reached. Waiting for speech completion...");
      }
    });

    _speech.statusListener = (status) {
      print("Speech recognition status: $status");

      if (status == "notListening") {
        _stopListening();
        isSpeechActive = false;
        _isListening = false;
        if (updatedWords.isNotEmpty) {
          _formFields[_currentFieldIndex]['value'] = updatedWords;
          _controllers[_currentFieldIndex].text = updatedWords;
        }

        print("Captured Words: ${_formFields[_currentFieldIndex]['value']}");

        Future.delayed(const Duration(seconds: 10), () async {
          if (_formFields[_currentFieldIndex]['value']!.isNotEmpty) {
            pauseTimer?.cancel();
            String fieldValue =
                _formFields[_currentFieldIndex]['value']!.trim();
            await _confirmAndStartListening(
              _formFields[_currentFieldIndex]['label']!,
              fieldValue,
            );

            if (_currentFieldIndex < _formFields.length - 1) {
              print("Switching to next field...");
              Future.delayed(const Duration(milliseconds: 500), _goToNextField);
            } else {
              print("All fields filled. Signing in...");
              _readMessage("All fields are filled. Signing in...");
              _signUp();
            }
          } else {
            print("No words captured, retrying...");
            _readMessage("I didn't hear anything. Please say it again.");
            Future.delayed(const Duration(seconds: 2), () {
              if (_formFields[_currentFieldIndex]['value']!.isEmpty) {
                _startListening(_formFields[_currentFieldIndex]['label']!);
              } else {
                Future.delayed(
                    const Duration(milliseconds: 500), _goToNextField);
              }
            });
          }
        });
      }
    };
  }

  Future<void> _confirmAndStartListening(
      String fieldLabel, String fieldValue) async {
    if (_isListening || _isProcessing) return;

    setState(() => _isListening = true);

    isSpeechActive = true;
    updatedWords = "";

    _readMessage(
        "Is $fieldValue your $fieldLabel? Say yes to continue or no to re-enter.");
    await flutterTts.awaitSpeakCompletion(true);

    bool confirmationReceived = false;
    Timer? pauseTimer;

    _speech.listen(
      onResult: (result) async {
        if (result.recognizedWords.isNotEmpty) {
          confirmationReceived = true;
          String confirmation = result.recognizedWords.toLowerCase().trim();

          if (confirmation.contains("yes")) {
            _stopListening();
            pauseTimer?.cancel();

            if (_currentFieldIndex == _formFields.length - 1 &&
                (_formFields[_currentFieldIndex]['value']?.isNotEmpty ??
                    false)) {
              _readMessage("All fields are filled. Signing you up now.");
              await flutterTts.awaitSpeakCompletion(true);
              await _signUp();
            } else {
              _goToNextField();
            }
          } else if (confirmation.contains("no")) {
            _stopListening();
            pauseTimer?.cancel();
            _readMessage("Please re-enter your $fieldLabel.");
            await flutterTts.awaitSpeakCompletion(true);
            _startListening(fieldLabel);
          } else if (confirmation.contains("exit") ||
              confirmation.contains("close")) {
            print("Closing the app...");
            _readMessage("Closing the app...");
            Future.delayed(const Duration(seconds: 1), () {
              SystemNavigator.pop();
            });
          }
        }
      },
      listenFor: const Duration(seconds: 20),
      pauseFor: const Duration(seconds: 10),
    );

    pauseTimer = Timer(const Duration(seconds: 10), () {
      if (!confirmationReceived && _isListening) {
        print("PauseFor timeout reached. Waiting for response...");
      }
    });

    _speech.statusListener = (status) {
      print("Speech recognition status: $status");

      if (status == "notListening") {
        _stopListening();
        isSpeechActive = false;
        _isListening = false;

        if (!confirmationReceived) {
          _readMessage("I didn't hear anything. Please try again.");
          Future.delayed(const Duration(seconds: 2), () {
            _confirmAndStartListening(fieldLabel, fieldValue);
          });
        }
      }
    };
  }

  void _stopListening() {
    _speech.stop();
    setState(() => _isListening = false);
  }

  void _goToNextField() async {
    _stopListening();

    if (_currentFieldIndex < _formFields.length - 1 &&
        _formFields[_currentFieldIndex]['value']!.isNotEmpty) {
      setState(() {
        _currentFieldIndex++;
        updatedWords = "";
        _controllers[_currentFieldIndex].clear();
      });

      await Future.delayed(const Duration(seconds: 1));
      _promptUser();
    }
  }

  void _readMessage(String message) async {
    await flutterTts.speak(message);
  }

  Future<void> _signUp() async {
    try {
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
              email: _formFields[0]['value']!,
              password: _formFields[1]['value']!);

      FirebaseFirestore firestore = FirebaseFirestore.instance;

      print("user credentials: $userCredential");
      String userId = userCredential.user!.uid;

      Map<String, dynamic> userData = {
        'email': _controllers[0].text,
        'password': _controllers[1].text,
        'phone': _controllers[2].text,
      };
      await firestore.collection('users').doc(userId).set(userData);

      if (userId.isNotEmpty) {
        print(userId.toString());

        // Store the sign-up state in SharedPreferences
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isSignedUp', true);

        if (!_isManualInput) {
          await flutterTts.speak("Sign Up successful");
          await flutterTts.awaitSpeakCompletion(true);
        }

        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const CameraScreen()));
      }
    } catch (e) {
      print("Error: $e");
      if (!_isManualInput) {
        await flutterTts.speak("error creating new account");
        await flutterTts.awaitSpeakCompletion(true);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign up failed. Please try again.')),
      );
      Future.delayed(const Duration(seconds: 5), () {
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

  void _handleManualSignUp() {
    if (_formFields.any((field) => field['value']!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }
    _signUp();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign Up')),
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
            ListView.builder(
              shrinkWrap: true,
              itemCount: _formFields.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: TextFormField(
                    controller: _controllers[index],
                    obscureText: _formFields[index]['label'] == 'Password',
                    decoration: InputDecoration(
                      labelText: _formFields[index]['label'],
                      hintText: 'Enter your ${_formFields[index]['label']}',
                    ),
                    onChanged: (value) {
                      _isManualInput = true;
                      setState(() {
                        _formFields[index]['value'] = value;
                      });
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _handleManualSignUp,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(200, 50),
              ),
              child: const Text('Sign Up', style: TextStyle(fontSize: 18)),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const SignInScreen()),
                );
              },
              child: const Text('Already have an account? Sign In'),
            ),
          ],
        ),
      ),
    );
  }
}
