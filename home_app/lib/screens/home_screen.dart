import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../constants.dart';
import '../services/signaling_service.dart';
import '../services/zego_service.dart';
import '../services/fcm_service.dart';
import 'call_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _calling = false;

  Future<void> _startCall() async {
    setState(() => _calling = true);

    try {
      await ZegoService.instance.initEngine();

      final callId = const Uuid().v4().substring(0, 8);
      final roomId = 'room_$callId';

      await SignalingService().initiateCall(
        callId: callId,
        roomId: roomId,
        callerId: ZegoConstants.webUserId,
        callerName: ZegoConstants.webUserName,
      );

      // Send FCM push notification for background/locked state
      await FcmService.sendCallNotification(
        callId: callId,
        roomId: roomId,
        callerName: ZegoConstants.webUserName,
      );

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CallScreen(callId: callId, roomId: roomId),
        ),
      );
    } catch (e, stack) {
      debugPrint('[HomeScreen] _startCall error: $e');
      debugPrint(stack.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting call: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _calling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Home App'),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xFF1976D2).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.support_agent,
                size: 64,
                color: Color(0xFF1976D2),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Call Executive',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Start a voice call with the executive',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 48),
            _calling
                ? const Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Calling executive...',
                          style: TextStyle(color: Colors.grey)),
                    ],
                  )
                : ElevatedButton.icon(
                    onPressed: _startCall,
                    icon: const Icon(Icons.call, size: 24),
                    label: const Text(
                      'Start Call',
                      style: TextStyle(fontSize: 18),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1976D2),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 48, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(32),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
