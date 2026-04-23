import 'dart:async';
import 'package:flutter/material.dart';
import '../constants.dart';
import '../models/call_model.dart';
import '../services/signaling_service.dart';
import '../services/zego_service.dart';
import 'home_screen.dart';

class CallScreen extends StatefulWidget {
  final CallModel call;

  const CallScreen({super.key, required this.call});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final _signaling = SignalingService();
  StreamSubscription<String>? _statusSub;
  bool _micMuted = false;
  int _callDuration = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _joinRoom();
    _watchStatus();
  }

  Future<void> _joinRoom() async {
    await ZegoService.instance.joinRoom(
      roomId: widget.call.roomId,
      userId: ZegoConstants.executiveId,
      userName: ZegoConstants.executiveName,
      streamId: ZegoConstants.executiveStreamId(widget.call.roomId),
    );

    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() => _callDuration++),
    );
  }

  void _watchStatus() {
    _statusSub =
        _signaling.watchCallStatus(widget.call.callId).listen((status) {
      if (!mounted) return;
      if (status == 'ended') _hangUp(callerEnded: true);
    });
  }

  Future<void> _hangUp({bool callerEnded = false}) async {
    _statusSub?.cancel();
    _timer?.cancel();

    await ZegoService.instance.leaveRoom(
      widget.call.roomId,
      ZegoConstants.executiveStreamId(widget.call.roomId),
    );

    if (!callerEnded) {
      await _signaling.updateCallStatus(widget.call.callId, 'ended');
    }

    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (_) => false,
      );
    }
  }

  String get _formattedDuration {
    final m = _callDuration ~/ 60;
    final s = _callDuration % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B5E20),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 60),
            const CircleAvatar(
              radius: 56,
              backgroundColor: Colors.white24,
              child: Icon(Icons.person, size: 64, color: Colors.white),
            ),
            const SizedBox(height: 24),
            Text(
              widget.call.callerName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _formattedDuration,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () async {
                    setState(() => _micMuted = !_micMuted);
                    await ZegoService.instance.toggleMic(_micMuted);
                  },
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.white24,
                        child: Icon(
                          _micMuted ? Icons.mic_off : Icons.mic,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _micMuted ? 'Unmute' : 'Mute',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: _hangUp,
              child: const Column(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: Colors.red,
                    child: Icon(Icons.call_end, color: Colors.white, size: 32),
                  ),
                  SizedBox(height: 8),
                  Text('End Call',
                      style:
                          TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}
