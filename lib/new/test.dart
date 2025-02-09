import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:testing/new/stt_service.dart';

class SignUpSignInPage extends StatefulWidget {
  const SignUpSignInPage({super.key});

  @override
  _SignUpSignInPageState createState() => _SignUpSignInPageState();
}

class _SignUpSignInPageState extends State<SignUpSignInPage>
    with WidgetsBindingObserver {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final SpeechService _speechService = SpeechService();
  bool _isListening = false;
  bool _speechDetected = false; // Tracks if speech was detected
  final bool _isSignUp = true;
  int _currentFieldIndex = 0;

  final List<Map<String, String>> _formFields = [
    {'label': 'Email Address', 'value': ''},
    {'label': 'Password', 'value': ''},
    {'label': 'Phone Number', 'value': ''},
    {'label': 'Gender', 'value': ''},
  ];

  // Variable to store the scheduled retry future to cancel it if necessary
  late Future<void> _scheduledRetry;
  final bool _retryScheduled = false; // Prevents retry stack-up

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeSpeech();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _speechService.stopListening();
    super.dispose();
  }

  void _initializeSpeech() async {
    bool available = await _speechService.initializeSpeech();
    if (!available) {
      _speechService.speak("Speech recognition is not available on this device.");
    } else {
      _promptUser();
    }
  }

  void _promptUser() {
    if (_currentFieldIndex >= _formFields.length) return;

    // Ensure we are not repeating the same field
    String fieldLabel = _formFields[_currentFieldIndex]['label']!;

    if (_isListening || _retryScheduled) {
      return; // Prevent duplicate triggers
    }

    setState(() {
      _speechDetected = false;
    });

    Future.delayed(const Duration(seconds: 1), () {
      if (!_isListening) {
        _startListening();
      }
    });
  }
// Track if timeout is active
// Flag to track if retry is in progress
// Flag to track if retry is in progress
bool _isRetryInProgress = false;

// Method to start listening with retry functionality
void _startListening({bool isRetry = false}) {
  if (_isListening || _currentFieldIndex >= _formFields.length) return;

  String fieldLabel = _formFields[_currentFieldIndex]['label']!;
  if (_formFields[_currentFieldIndex]['value']!.isNotEmpty) return;

  print("${isRetry ? "Retrying" : "Listening"} for: $fieldLabel");

  setState(() {
    _isListening = true; // Indicate that listening has started
    _speechDetected = false;
  });

  // Speak to prompt the user
  _speechService.speak(
    isRetry
        ? "I didn't hear anything. Please try again."
        : "Please say your $fieldLabel.",
    onComplete: () {
      print("Speech completed. Starting speech recognition...");
      
      // If retry is already in progress, skip scheduling another one
      if (_isRetryInProgress) {
        print("Retry already in progress, skipping...");
        return;
      }

      // Set the flag to indicate retry is in progress
      _isRetryInProgress = true;

      // Set a timeout after speech completion, before starting recognition
      Future.delayed(const Duration(seconds: 15), () {
        if (!_speechDetected) {
          print("Still no speech detected, retrying...");
          _stopListening();
          _scheduleRetry(); // Ensure retry happens if no speech detected
        } else {
          _isRetryInProgress = false; // Reset retry flag if speech detected
        }
      });

      // Start listening after a brief delay
      Future.delayed(Duration(seconds: 1), () {
        _speechService.startListening((recognizedWords) {
          print("Inside callback, words detected: $recognizedWords");
          if (recognizedWords.isNotEmpty) {
            print("Recognized for ${_formFields[_currentFieldIndex]['label']}: $recognizedWords");
            setState(() {
              _speechDetected = true;
              _formFields[_currentFieldIndex]['value'] = recognizedWords;
            });

            _stopListening();
            Future.delayed(const Duration(seconds: 1), _goToNextField);
          } else {
            print("No speech detected, scheduling retry...");
            _stopListening();
            _scheduleRetry(); // Ensure retry happens if no speech detected
          }
        });
      });
    },
  );
}

// Method to stop listening
void _stopListening() {
  _speechService.stopListening();
  setState(() {
    _isListening = false; // Reset the flag once listening stops
  });
}

// Method to schedule retry
void _scheduleRetry() {
  if (_isRetryInProgress || _speechDetected || _formFields[_currentFieldIndex]['value']!.isNotEmpty) {
    // Don't schedule a retry if the field is filled or retry is already in progress
    return;
  }

  print("Scheduling retry...");
  setState(() {
    _isRetryInProgress = true; // Mark retry as in progress
  });

  // Delay the retry to give time for any other processes to complete
  Future.delayed(const Duration(seconds: 2), () {
    if (_formFields[_currentFieldIndex]['value']!.isEmpty && !_speechDetected) {
      print("Retrying for: ${_formFields[_currentFieldIndex]['label']}");
      _startListening(isRetry: true); // Retry again
    } else {
      setState(() {
        _isRetryInProgress = false; // Reset retry flag if field is filled
      });
    }
  });
}




  void _goToNextField() {
    if (_isListening || !_speechDetected) return;

    if (_currentFieldIndex < _formFields.length - 1) {
      setState(() {
        _currentFieldIndex++;
      });

      Future.delayed(const Duration(milliseconds: 500), () {
        if (!_isListening) {
          _startListening(); // Start listening for the new field
        }
      });
    } else {
      _speechService.speak(
          "All fields are filled. Say 'Sign Up' or 'Sign In' to proceed.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isSignUp ? 'Sign Up' : 'Sign In')),
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
              controller: TextEditingController(
                  text: _formFields[_currentFieldIndex]['value']),
              decoration: InputDecoration(
                labelText: _formFields[_currentFieldIndex]['label'],
              ),
              enabled: false, // Disable to ensure speech fills the field
            ),
          ],
        ),
      ),
    );
  }
}
