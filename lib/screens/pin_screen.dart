import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';

enum PinMode { create, verify, update }

class PinScreen extends StatefulWidget {
  final PinMode mode;
  final VoidCallback? onSuccess;

  const PinScreen({super.key, required this.mode, this.onSuccess});

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> {
  final List<String> _pin = [];
  String _tempPin = ''; // For confirm step in create/update mode
  bool _isConfirming = false;
  bool _isLoading = false;
  String _message = '';

  @override
  void initState() {
    super.initState();
    _updateMessage();
  }

  void _updateMessage() {
    setState(() {
      if (widget.mode == PinMode.verify) {
        _message = 'Enter your PIN';
      } else if (widget.mode == PinMode.create ||
          widget.mode == PinMode.update) {
        if (_isConfirming) {
          _message = 'Confirm your PIN';
        } else {
          _message = widget.mode == PinMode.create
              ? 'Create a PIN'
              : 'Enter new PIN';
        }
      }
    });
  }

  void _onNumberPress(String number) {
    if (_pin.length < 6) {
      setState(() {
        _pin.add(number);
      });
      if (_pin.length == 6) {
        _handlePinComplete();
      }
    }
  }

  void _onDeletePress() {
    if (_pin.isNotEmpty) {
      setState(() {
        _pin.removeLast();
      });
    }
  }

  Future<void> _handlePinComplete() async {
    final pinString = _pin.join();

    if (widget.mode == PinMode.verify) {
      await _verifyPin(pinString);
    } else {
      _handleCreateUpdatePin(pinString);
    }
  }

  Future<void> _verifyPin(String enteredPin) async {
    setState(() => _isLoading = true);
    try {
      final authService = context.read<AuthService>();
      final firestoreService = context.read<FirestoreService>();
      final user = authService.currentUser;

      if (user != null) {
        final userModel = await firestoreService.getUser(user.uid);
        if (userModel?.pin == enteredPin) {
          if (widget.onSuccess != null) {
            widget.onSuccess!();
          } else {
            Navigator.pop(context, true);
          }
        } else {
          _showError('Incorrect PIN');
          setState(() {
            _pin.clear();
          });
        }
      }
    } catch (e) {
      _showError('Error verifying PIN');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleCreateUpdatePin(String enteredPin) async {
    if (!_isConfirming) {
      setState(() {
        _tempPin = enteredPin;
        _isConfirming = true;
        _pin.clear();
        _updateMessage();
      });
    } else {
      if (enteredPin == _tempPin) {
        await _savePin(enteredPin);
      } else {
        _showError('PINs do not match. Try again.');
        setState(() {
          _isConfirming = false;
          _pin.clear();
          _tempPin = '';
          _updateMessage();
        });
      }
    }
  }

  Future<void> _savePin(String newPin) async {
    setState(() => _isLoading = true);
    try {
      final authService = context.read<AuthService>();
      final firestoreService = context.read<FirestoreService>();
      final user = authService.currentUser;

      if (user != null) {
        await firestoreService.setPin(user.uid, newPin);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('PIN set successfully')));
          if (widget.onSuccess != null) {
            widget.onSuccess!();
          } else {
            Navigator.pop(context);
          }
        }
      }
    } catch (e) {
      _showError('Failed to save PIN');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 60),
            const Icon(Icons.lock_outline, size: 48, color: Colors.blue),
            const SizedBox(height: 24),
            Text(
              _message,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(6, (index) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: index < _pin.length
                        ? Colors.blue
                        : Colors.grey.shade300,
                  ),
                );
              }),
            ),
            const Spacer(),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else
              _buildNumberPad(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberPad() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          _buildRow(['1', '2', '3']),
          const SizedBox(height: 20),
          _buildRow(['4', '5', '6']),
          const SizedBox(height: 20),
          _buildRow(['7', '8', '9']),
          const SizedBox(height: 20),
          _buildRow(['', '0', 'back']),
        ],
      ),
    );
  }

  Widget _buildRow(List<String> keys) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: keys.map((key) {
        if (key.isEmpty) return const SizedBox(width: 70, height: 70);
        if (key == 'back') {
          return InkWell(
            onTap: _onDeletePress,
            borderRadius: BorderRadius.circular(35),
            child: const SizedBox(
              width: 70,
              height: 70,
              child: Icon(Icons.backspace_outlined, size: 28),
            ),
          );
        }
        return InkWell(
          onTap: () => _onNumberPress(key),
          borderRadius: BorderRadius.circular(35),
          child: Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey.shade100,
            ),
            alignment: Alignment.center,
            child: Text(
              key,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w500),
            ),
          ),
        );
      }).toList(),
    );
  }
}
