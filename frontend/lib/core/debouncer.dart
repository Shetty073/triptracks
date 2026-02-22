import 'dart:async';
import 'package:flutter/material.dart';

/// A simple debouncer that delays execution of [run] until no new calls
/// arrive within [delay]. Prevents excessive API calls on rapid input.
///
/// Usage:
/// ```dart
/// final _debouncer = Debouncer();
///
/// // In onChanged:
/// _debouncer.run(() => myApiCall(value));
///
/// // In dispose():
/// _debouncer.dispose();
/// ```
class Debouncer {
  final Duration delay;
  Timer? _timer;

  Debouncer({this.delay = const Duration(milliseconds: 400)});

  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  void dispose() {
    _timer?.cancel();
  }
}
