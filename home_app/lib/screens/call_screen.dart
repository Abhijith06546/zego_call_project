import 'dart:async';
import 'package:flutter/material.dart';
import '../constants.dart';
import '../services/signaling_service.dart';
import '../services/zego_service.dart';

class CallScreen extends StatefulWidget {
  final String callId;
  final String roomId;

  const CallScreen({super.key, required this.callId, required this.roomId});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final _signaling = SignalingService();
  StreamSubscription<String>? _statusSub;

  String _status = 'Ringing...';
  bool _inCall = false;
  bool _micMuted = false;
  int _callDuration = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _watchCallStatus();
  }

  void _watchCallStatus() {
    _statusSub = _signaling.watchCallStatus(widget.callId).listen(
      (status) {
        if (!mounted) return;
        switch (status) {
          case 'accepted':
            _onCallAccepted();
          case 'rejected':
            _onCallRejected();
          case 'ended':
            _onCallEnded();
        }
      },
      onError: (e, stack) {
        debugPrint('[CallScreen] watchCallStatus error: $e');
        debugPrint(stack.toString());
      },
    );
  }

  Future<void> _onCallAccepted() async {
    setState(() {
      _status = 'Connected';
      _inCall = true;
    });

    try {
      await ZegoService.instance.joinRoom(
        roomId: widget.roomId,
        userId: ZegoConstants.webUserId,
        userName: ZegoConstants.webUserName,
        streamId: ZegoConstants.callerStreamId(widget.roomId),
      );
    } catch (e, stack) {
      debugPrint('[CallScreen] joinRoom failed: $e');
      debugPrint(stack.toString());
      if (mounted) setState(() => _status = 'Connection failed');
      return;
    }

    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() => _callDuration++),
    );
  }

  void _onCallRejected() {
    setState(() => _status = 'Call Rejected');
    Future.delayed(const Duration(seconds: 2), _hangUp);
  }

  void _onCallEnded() {
    if (_inCall) _hangUp();
  }

  Future<void> _hangUp() async {
    _statusSub?.cancel();
    _timer?.cancel();

    try {
      if (_inCall) {
        await ZegoService.instance.leaveRoom(
          widget.roomId,
          ZegoConstants.callerStreamId(widget.roomId),
        );
      }
      await _signaling.updateCallStatus(widget.callId, 'ended');
    } catch (e, stack) {
      debugPrint('[CallScreen] _hangUp error: $e');
      debugPrint(stack.toString());
    }

    if (mounted) Navigator.pop(context);
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
      backgroundColor: const Color(0xFF1A237E),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 60),
            const CircleAvatar(
              radius: 56,
              backgroundColor: Colors.white24,
              child: Icon(Icons.support_agent, size: 64, color: Colors.white),
            ),
            const SizedBox(height: 24),
            const Text(
              'Executive',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _inCall ? _formattedDuration : _status,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            if (!_inCall && _status == 'Ringing...')
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white54,
                  ),
                ),
              ),
            const Spacer(),
            if (_inCall)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _ActionButton(
                    icon: _micMuted ? Icons.mic_off : Icons.mic,
                    label: _micMuted ? 'Unmute' : 'Mute',
                    color: Colors.white24,
                    onTap: () async {
                      setState(() => _micMuted = !_micMuted);
                      await ZegoService.instance.toggleMic(_micMuted);
                    },
                  ),
                ],
              ),
            const SizedBox(height: 32),
            _ActionButton(
              icon: Icons.call_end,
              label: 'End Call',
              color: Colors.red,
              size: 72,
              onTap: _hangUp,
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final double size;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.size = 56,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(
            radius: size / 2,
            backgroundColor: color,
            child: Icon(icon, color: Colors.white, size: size * 0.5),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }
}
