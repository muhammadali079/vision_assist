import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:testing/new/camera_screen.dart';
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

  bool _isListening = false;
  bool isSpeechActive = false;
  int _currentFieldIndex = 0;
  String updatedWords = "";
  bool _isManualInput = false;

  final List<Map<String, String>> _formFields = [
    {'label': 'Email Address', 'value': ''},
    {'label': 'Password', 'value': ''},
  ];

  final List<TextEditingController> _controllers = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkSignInState(); // Add this line
    _initializeSpeech();
    _initializeControllers();
    _promptUser();
  }

  void _checkSignInState() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isSignedIn = prefs.getBool('isSignedIn') ?? false;

    if (isSignedIn) {
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
    _stopListening();
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _initializeSpeech() async {
    bool available = await _speech.initialize();
    if (!available) {
      _readMessage("Speech recognition is not available on this device.");
    }
  }

  void _promptUser() {
    if (_currentFieldIndex < _formFields.length &&
        !_isListening &&
        !isSpeechActive) {
      Future.delayed(const Duration(milliseconds: 200), () {
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
              updatedWords.contains("sign up")) {
            print("Navigating to Sign Up screen...");
            _readMessage("Switching to Sign Up screen...");
            Future.delayed(const Duration(seconds: 1), () {
              Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (_) => const SignUpScreen()));
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
              _signIn();
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
    if (_isListening) return;

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
              _readMessage("All fields are filled. Signing in now.");
              await flutterTts.awaitSpeakCompletion(true);
              await _signIn();
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

  void _stopListening() {
    _speech.stop();
    setState(() => _isListening = false);
  }

  void _readMessage(String message) async {
    await flutterTts.speak(message);
    await flutterTts.awaitSpeakCompletion(true);
  }

  Future<void> _signIn() async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: _formFields[0]['value']!,
        password: _formFields[1]['value']!,
      );

      if (!_isManualInput) {
        _readMessage("Sign in successful. Welcome back!");
        await flutterTts.awaitSpeakCompletion(true);
      }

      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isSignedIn', true);

      if (context.mounted) {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const CameraScreen()));
      }
    } catch (e) {
      if (!_isManualInput) {
        await flutterTts.speak("Error signing in. Please try again.");
        await flutterTts.awaitSpeakCompletion(true);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in failed. Please try again.')),
      );
      Future.delayed(const Duration(seconds: 2), _resetForm);
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

    Future.delayed(const Duration(seconds: 2), _promptUser);
  }

  void _handleManualSignIn() {
    if (_formFields[0]['value']!.isEmpty || _formFields[1]['value']!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }
    _signIn();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign In')),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.1),
                Text(
                  "Current Field: ${_formFields[_currentFieldIndex]['label']}",
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ListView.builder(
                  physics: const NeverScrollableScrollPhysics(),
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
                  onPressed: _handleManualSignIn,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(200, 50),
                  ),
                  child: const Text('Sign In', style: TextStyle(fontSize: 18)),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const SignUpScreen()),
                    );
                  },
                  child: const Text('Don\'t have an account? Sign Up'),
                ),
                SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
