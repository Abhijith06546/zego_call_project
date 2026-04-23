import 'dart:async';
import 'package:flutter/material.dart';
import '../models/call_model.dart';
import '../services/signaling_service.dart';
import '../services/zego_service.dart';
import 'call_screen.dart';
import 'home_screen.dart';

class IncomingCallScreen extends StatefulWidget {
  final CallModel call;

  const IncomingCallScreen({super.key, required this.call});

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  final _signaling = SignalingService();
  StreamSubscription<String>? _statusSub;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    _watchForCancellation();
  }

  void _watchForCancellation() {
    _statusSub = _signaling
        .watchCallStatus(widget.call.callId)
        .listen((status) {
      if (!mounted) return;
      if (status == 'ended') _returnHome();
    });
  }

  Future<void> _acceptCall() async {
    if (_processing) return;
    setState(() => _processing = true);

    _statusSub?.cancel();
    await ZegoService.instance.initEngine();
    await _signaling.updateCallStatus(widget.call.callId, 'accepted');

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => CallScreen(call: widget.call),
      ),
    );
  }

  Future<void> _rejectCall() async {
    if (_processing) return;
    setState(() => _processing = true);

    _statusSub?.cancel();
    await _signaling.updateCallStatus(widget.call.callId, 'rejected');
    _returnHome();
  }

  void _returnHome() {
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A237E),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 80),
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
            const Text(
              'Incoming Voice Call',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 16),
            _PulsingRing(),
            const Spacer(),
            if (_processing)
              const CircularProgressIndicator(color: Colors.white)
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _CallActionButton(
                    icon: Icons.call_end,
                    label: 'Reject',
                    color: Colors.red,
                    onTap: _rejectCall,
                  ),
                  _CallActionButton(
                    icon: Icons.call,
                    label: 'Accept',
                    color: Colors.green,
                    onTap: _acceptCall,
                  ),
                ],
              ),
            const SizedBox(height: 64),
          ],
        ),
      ),
    );
  }
}

class _PulsingRing extends StatefulWidget {
  @override
  State<_PulsingRing> createState() => _PulsingRingState();
}

class _PulsingRingState extends State<_PulsingRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.8, end: 1.2).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _animation,
      child: const Icon(Icons.ring_volume, color: Colors.white54, size: 48),
    );
  }
}

class _CallActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _CallActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: color,
            child: Icon(icon, color: Colors.white, size: 32),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: const TextStyle(color: Colors.white, fontSize: 14)),
        ],
      ),
    );
  }
}
