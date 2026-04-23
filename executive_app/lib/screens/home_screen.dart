import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/signaling_service.dart';
import '../models/call_model.dart';
import 'incoming_call_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _signaling = SignalingService();
  StreamSubscription<CallModel?>? _callSub;
  String _fcmToken = 'Registering...';

  @override
  void initState() {
    super.initState();
    _requestMicPermission();
    _registerFcm();
    _listenForCalls();
  }

  Future<void> _requestMicPermission() async {
    final status = await Permission.microphone.request();
    debugPrint('[HomeScreen] Microphone permission: $status');
  }

  Future<void> _registerFcm() async {
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      final token = await messaging.getToken();
      if (token != null) {
        setState(() => _fcmToken = token);
        await _signaling.saveExecutiveFcmToken(token);
      } else {
        debugPrint('[HomeScreen] FCM token is null');
      }
    } catch (e, stack) {
      debugPrint('[HomeScreen] _registerFcm error: $e');
      debugPrint(stack.toString());
    }
  }

  void _listenForCalls() {
    _callSub = _signaling.watchIncomingCall().listen(
      (call) {
        if (call == null || !mounted) return;
        _showIncomingCall(call);
      },
      onError: (error, stack) {
        debugPrint('[HomeScreen] watchIncomingCall error: $error');
        debugPrint(stack.toString());
        // Retry after 5 seconds (e.g. while Firestore index is still building)
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted) _listenForCalls();
        });
      },
    );
  }

  void _showIncomingCall(CallModel call) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => IncomingCallScreen(call: call),
      ),
    );
  }

  @override
  void dispose() {
    _callSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Executive App'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.headset_mic,
                  size: 64,
                  color: Color(0xFF2E7D32),
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Waiting for Calls',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'You will be notified when a web user calls',
                style: TextStyle(fontSize: 14, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.circle, color: Colors.green, size: 12),
                    const SizedBox(width: 8),
                    const Text('Status: Online',
                        style: TextStyle(fontWeight: FontWeight.w500)),
                    const Spacer(),
                    const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('FCM Token (for testing):',
                        style:
                            TextStyle(fontSize: 11, color: Colors.grey)),
                    const SizedBox(height: 4),
                    SelectableText(
                      _fcmToken,
                      style: const TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
