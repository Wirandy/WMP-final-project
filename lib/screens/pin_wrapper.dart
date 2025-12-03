import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/user_model.dart';
import 'pin_screen.dart';
import 'main_screen.dart';

class PinWrapper extends StatefulWidget {
  const PinWrapper({super.key});

  @override
  State<PinWrapper> createState() => _PinWrapperState();
}

class _PinWrapperState extends State<PinWrapper> {
  bool _isVerified = false;
  bool _isLoading = true;
  bool _hasPin = false;

  @override
  void initState() {
    super.initState();
    _checkPinStatus();
  }

  Future<void> _checkPinStatus() async {
    try {
      final authService = context.read<AuthService>();
      final firestore = context.read<FirestoreService>();
      final user = authService.currentUser;

      if (user != null) {
        final userModel = await firestore.getUser(user.uid);
        if (mounted) {
          setState(() {
            _hasPin = userModel?.pin != null && userModel!.pin!.isNotEmpty;
          });
        }
      }
    } catch (e) {
      debugPrint('Error checking PIN status: $e');
      // Fallback: if error, assume no PIN or handle gracefully
      // For now, we just stop loading so user isn't stuck
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onPinVerified() {
    setState(() {
      _isVerified = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // If user has no PIN, force them to create one
    if (!_hasPin) {
      return PinScreen(
        mode: PinMode.create,
        onSuccess: () {
          setState(() {
            _hasPin = true;
            _isVerified = true;
          });
        },
      );
    }

    // If user has PIN but not verified, show Verify screen
    if (!_isVerified) {
      return PinScreen(mode: PinMode.verify, onSuccess: _onPinVerified);
    }

    // If verified (or just created), show MainScreen
    return const MainScreen();
  }
}
