import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:home_app/firebase_options.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  FlutterError.onError = (details) {
    debugPrint('[FlutterError] ${details.exceptionAsString()}');
    debugPrint(details.stack.toString());
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('[PlatformError] $error');
    debugPrint(stack.toString());
    return true;
  };

  // ensureInitialized must be in the same zone as runApp.
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    } catch (e, stack) {
      debugPrint('[main] Firebase init failed: $e');
      debugPrint(stack.toString());
    }

    // Sign in anonymously so Callable Functions accept requests from this client.
    try {
      await FirebaseAuth.instance.signInAnonymously();
      debugPrint('[main] Signed in anonymously');
    } catch (e, stack) {
      debugPrint('[main] Anonymous sign-in failed: $e');
      debugPrint(stack.toString());
    }

    runApp(const HomeApp());
  }, (error, stack) {
    debugPrint('[ZoneError] $error');
    debugPrint(stack.toString());
  });
}

class HomeApp extends StatelessWidget {
  const HomeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zego Home App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1976D2)),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
