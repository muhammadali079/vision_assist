import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:testing/screens/camera_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SignupScreen extends StatefulWidget {
  final VoidCallback toggleView;
  const SignupScreen({super.key, required this.toggleView});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _userExists = false;
  int _currentFieldIndex = 0;
  bool _isListening = false;
  bool _isSpeaking = false;
  final List<String> _fieldNames = [
    'gender',
    'name',
    'surname',
    'date of birth',
    'email',
    'phone number'
  ];

  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _initializeSpeech();
    _setupTTS();
    Future.delayed(const Duration(seconds: 1), _startVoiceGuidance);
  }

  void _setupTTS() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.4);
    _tts.setStartHandler(() => setState(() => _isSpeaking = true));
    _tts.setCompletionHandler(() => setState(() => _isSpeaking = false));
  }

  Future<void> _startVoiceGuidance() async {
    await _speakInstruction();
    await Future.delayed(const Duration(milliseconds: 500));
    _startListening();
  }

  Future<void> _speakInstruction() async {
    String instruction;
    switch (_currentFieldIndex) {
      case 0:
        instruction =
            "Please say your gender. Examples: male, female, non-binary. Say 'next' when done";
        break;
      case 1:
        instruction = "Please say your first name. Say 'next' when ready";
        break;
      case 2:
        instruction = "Please say your last name. Say 'next' to continue";
        break;
      case 3:
        instruction =
            "Please select your birth date. Tap the calendar icon or say 'next' to skip";
        break;
      case 4:
        instruction =
            "Please say your email address. Example: user@example.com. Say 'next' when done";
        break;
      case 5:
        instruction =
            "Please say your phone number including country code. Say 'next' to validate";
        break;
      default:
        instruction = "Please provide the required information";
    }
    await _tts.speak(instruction);
    await _tts.awaitSpeakCompletion(true);
  }

  Future<void> _startListening() async {
    if (!_isListening && !_isSpeaking && mounted) {
      await _speech.listen(
        onResult: (result) => _handleSpeechResult(result.recognizedWords),
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
      );
      if (mounted) setState(() => _isListening = true);
    }
  }

  void _handleSpeechResult(String words) async {
    if (_isSpeaking || !mounted) return;

    words = words.toLowerCase().trim();
    debugPrint('Raw input: $words');

    // Enhanced command detection
    final isNextCommand = words.contains('next');
    final cleanedInput = words.replaceAll('next', '').trim();

    if (isNextCommand) {
      await _handleNextCommand();
      return;
    }

    if (cleanedInput.isNotEmpty) {
      _controllers[_currentFieldIndex].text = cleanedInput;
      if (mounted) setState(() {});
    }
  }

  Future<void> _handleNextCommand() async {
    await _speech.stop();
    if (mounted) setState(() => _isListening = false);

    if (!mounted) return;

    final nextIndex = _currentFieldIndex + 1;

    // Validate field progression
    if (nextIndex >= _fieldNames.length) {
      await _tts.speak("Validating form");
      if (mounted) _signUp();
      return;
    }

    debugPrint(
        'Moving from ${_fieldNames[_currentFieldIndex]} to ${_fieldNames[nextIndex]}');

    if (mounted) {
      setState(() => _currentFieldIndex = nextIndex);
      FocusScope.of(context).requestFocus(_focusNodes[nextIndex]);
      _controllers[nextIndex].text = ''; // Clear previous input
    }

    await _speakInstruction();
    await _startListening();
  }

  Future<void> _initializeSpeech() async => await _speech.initialize();

  Future<void> _signUp() async {
    if (_formKey.currentState!.validate()) {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString('email') == _controllers[4].text) {
        if (mounted) setState(() => _userExists = true);
        if (_userExists) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('User already exists!')),
          );
        }
        return;
      }

      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('name', _controllers[1].text);
      await prefs.setString('email', _controllers[4].text);
      FirebaseFirestore firestore = FirebaseFirestore.instance;

      try {
        UserCredential userCredential =
            await _auth.createUserWithEmailAndPassword(
          email: _controllers[4].text,
          password: _controllers[5].text,
        );

        print("user credentials: $userCredential");
        String userId = userCredential.user!.uid;

        Map<String, dynamic> userData = {
          'name': _controllers[1].text,
          'surname': _controllers[2].text,
          'email': _controllers[4].text,
          'gender': _controllers[0].text,
          'dob': _controllers[3].text,
          'createdAt': FieldValue.serverTimestamp(),
        };
        await firestore.collection('users').doc(userId).set(userData);
        if (userId.isNotEmpty) {
          print(userId.toString());
          Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (_) => const CameraScreen()));
        }
      } catch (e) {
        print("Error storing user data in Firestore: $e");
      }
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) {
      _controllers[3].text = DateFormat('yyyy-MM-dd').format(picked);
      setState(() {});
      await Future.delayed(const Duration(milliseconds: 500));
      await _handleNextCommand();
    }
  }

  @override
  void dispose() {
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF6366F1), Color(0xFF4338CA)],
          ),
        ),
        child: SafeArea(
          child: GestureDetector(
            onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    const SizedBox(height: 40),
                    _buildVoiceStatusIndicator(),
                    const SizedBox(height: 20),
                    ..._buildFormFields(),
                    const SizedBox(height: 32),
                    _buildSignUpButton(),
                    TextButton(
                      onPressed: widget.toggleView,
                      child: const Text('Already have an account? Sign '),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildFormFields() {
    final labels = [
      'Gender',
      'Name',
      'Surname',
      'Date of Birth',
      'Email',
      'Phone Number'
    ];
    return List.generate(
        6,
        (index) =>
            _buildInputField(labels[index], _controllers[index], index: index));
  }

  Widget _buildInputField(String label, TextEditingController controller,
      {int? index}) {
    final currentIndex = index ?? 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: TextFormField(
        focusNode: _focusNodes[currentIndex],
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: _getPrefixIcon(index),
          suffixIcon: IconButton(
            icon: Icon(
              _speech.isListening ? Icons.mic_off : Icons.mic,
              color: _currentFieldIndex == currentIndex
                  ? Colors.amber
                  : Colors.grey,
            ),
            onPressed: () => _handleFieldMicButton(currentIndex),
          ),
          filled: true,
          fillColor: _focusNodes[currentIndex].hasFocus
              ? const Color.fromARGB(255, 255, 234, 170).withValues()
              : Colors.white.withValues(),
          focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Colors.amber, width: 2.0),
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
        validator: (value) => _validateField(value, label, index),
        onTap: () {
          if (index == 3) {
            _selectDate();
          } else if (mounted) {
            setState(() => _currentFieldIndex = currentIndex);
            FocusScope.of(context).requestFocus(_focusNodes[currentIndex]);
          }
        },
        readOnly: index == 3,
      ),
    );
  }

  Future<void> _handleFieldMicButton(int fieldIndex) async {
    if (mounted) {
      setState(() => _currentFieldIndex = fieldIndex);
      FocusScope.of(context).requestFocus(_focusNodes[fieldIndex]);
    }
    await _speakInstruction();
    await _startListening();
  }

  Icon? _getPrefixIcon(int? index) {
    final icons = [
      Icons.person,
      Icons.person_outline,
      Icons.family_restroom,
      Icons.cake,
      Icons.email,
      Icons.phone
    ];
    return Icon(icons[index ?? 0], color: Colors.deepPurple.withOpacity(0.6));
  }

  String? _validateField(String? value, String label, int? index) {
    if (value!.isEmpty) return 'Please enter $label';
    if (index == 4 && !value.contains('@')) return 'Invalid email';
    if (index == 5 && value.length < 10) return 'Invalid phone number';
    return null;
  }

  Widget _buildSignUpButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _signUp,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.deepPurple,
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 40),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: const Text(
          'Sign Up',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildVoiceStatusIndicator() {
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: _isListening ? 100 : 80,
          height: _isListening ? 100 : 80,
          decoration: BoxDecoration(
            color: _isListening
                ? Colors.amber.withOpacity(0.2)
                : Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: Icon(
            _isListening ? Icons.mic : Icons.mic_off,
            color: _isListening ? Colors.amber : Colors.white,
            size: 40,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          _isSpeaking
              ? "Please listen..."
              : _isListening
                  ? "Speak now..."
                  : "Tap mic to start",
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
      ],
    );
  }
}
