import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:testing/new/camera_screen.dart';
import 'package:testing/new/signin_screen.dart';
import 'package:testing/new/signup_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  runApp(
    const MyApp(),
  );
}

final appTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: Colors.deepPurple,
    brightness: Brightness.light,
  ),
  useMaterial3: true,
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white.withOpacity(0.95),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Colors.grey, width: 1.5),
    ),
    focusedBorder: const OutlineInputBorder(
      borderSide: BorderSide(color: Colors.amber, width: 2.5),
      borderRadius: BorderRadius.all(Radius.circular(16)),
    ),
    floatingLabelStyle: const TextStyle(
      color: Colors.white,
      backgroundColor: Colors.deepPurple,
      fontSize: 16,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.8,
    ),
    labelStyle: const TextStyle(
      color: Colors.deepPurple,
      fontSize: 16,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
  ),
);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: appTheme,
      home: const AuthWrapper(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool isLoggedIn = false;
  bool isSignIn = false;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      //isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
      isLoggedIn = false;
    });
  }

  @override
  Widget build(BuildContext context) {
//  return isLoggedIn
//     ? const CameraScreen()
//       : SignInScreen();
    return  CameraScreen();
  }
}
