import 'package:app/models/appState.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class JoinClubScreen extends StatefulWidget {
  const JoinClubScreen({super.key});

  @override
  State<JoinClubScreen> createState() => _JoinClubScreenState();
}

class _JoinClubScreenState extends State<JoinClubScreen> {
  final _codeController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _sendRequest() async {
    final code = _codeController.text.trim();
    if (code.length != 5) {
      setState(() => _error = 'Invite codes are exactly 5 characters.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await context.read<StateModel>().sendJoinRequest(code);
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: const Color.fromARGB(255, 250, 243, 220),
            title: const Text(
              'Request sent!',
              style: TextStyle(
                color: Color.fromARGB(255, 70, 40, 20),
                fontWeight: FontWeight.bold,
              ),
            ),
            content: const Text(
              'The club founder will review your request. You\'ll be added once they approve it.',
              style: TextStyle(color: Color.fromARGB(200, 70, 40, 20)),
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 110, 60, 60),
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 221, 209, 153),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 207, 178, 141),
        elevation: 0,
        title: const Text(
          'Join a Club',
          style: TextStyle(
            color: Color.fromARGB(255, 70, 40, 20),
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: const IconThemeData(
          color: Color.fromARGB(255, 110, 60, 60),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Invite code',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
                color: Color.fromARGB(160, 70, 40, 20),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _codeController,
              autofocus: true,
              maxLength: 5,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Fa-f0-9]')),
              ],
              decoration: InputDecoration(
                hintText: 'e.g. A3F9C',
                hintStyle: const TextStyle(
                    color: Color.fromARGB(120, 70, 40, 20)),
                filled: true,
                fillColor: const Color.fromARGB(220, 255, 250, 235),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                counterText: '',
                errorText: _error,
              ),
              style: const TextStyle(
                color: Color.fromARGB(255, 70, 40, 20),
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 8,
              ),
              onSubmitted: (_) => _sendRequest(),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _sendRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 110, 60, 60),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Send Request',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}