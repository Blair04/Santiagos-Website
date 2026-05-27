import 'dart:async';
import 'package:flutter/material.dart';

class SessionListener extends StatefulWidget {
  final Widget child;
  final VoidCallback onTimeout;
  final Duration duration;

  const SessionListener({
    super.key,
    required this.child,
    required this.onTimeout,
    this.duration = const Duration(minutes: 20), // Defaults to 20 minutes
  });

  @override
  State<SessionListener> createState() => _SessionListenerState();
}

class _SessionListenerState extends State<SessionListener> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // Starts or resets the inactivity timer
  void _startTimer() {
    _timer?.cancel(); 
    _timer = Timer(widget.duration, () {
      widget.onTimeout(); 
    });
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _startTimer(), // Reset timer on interaction
      onPointerMove: (_) => _startTimer(),
      child: widget.child,
    );
  }
}