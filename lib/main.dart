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
  bool isSignedUp = false;
  bool isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      isSignedUp = prefs.getBool('isSignedUp') ?? false;
      isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    });
  }

  // @override
  // Widget build(BuildContext context) {
  //   if (isLoggedIn) {
  //     return const CameraScreen();
  //   } else if (isSignedUp) {
  //     return const SignInScreen();
  //   } else {
  //     return const SignUpScreen();
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    // Testing logic: Uncomment one of the following to test individual screens.

    // To test the SignUpScreen only:
    // return const SignUpScreen();

    // To test the SignInScreen only:
    // return const SignInScreen();

    // To test the CameraScreen only:
    return const CameraScreen();

    // Default logic: This handles the original flow.
    // if (isLoggedIn) {
    // return const CameraScreen();
    // } else if (isSignedUp) {
    //   return const SignInScreen();
    // } else {
    //   return const SignUpScreen();
    // }
  }
}
