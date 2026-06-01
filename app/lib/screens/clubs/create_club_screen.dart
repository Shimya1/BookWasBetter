import 'package:app/models/appState.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class CreateClubScreen extends StatefulWidget {
  const CreateClubScreen({super.key});

  @override
  State<CreateClubScreen> createState() => _CreateClubScreenState();
}

class _CreateClubScreenState extends State<CreateClubScreen> {
  final _nameController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Please enter a club name.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await context.read<StateModel>().createClub(name);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = 'Failed to create club. Please try again.');
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
          'Create a Club',
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
              'Club name',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
                color: Color.fromARGB(160, 70, 40, 20),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: 'e.g. The Page Turners',
                hintStyle: const TextStyle(
                    color: Color.fromARGB(120, 70, 40, 20)),
                filled: true,
                fillColor: const Color.fromARGB(220, 255, 250, 235),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                errorText: _error,
              ),
              style: const TextStyle(
                  color: Color.fromARGB(255, 70, 40, 20)),
              onSubmitted: (_) => _create(),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _create,
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
                        'Create Club',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
              ),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color.fromARGB(100, 255, 250, 235),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color.fromARGB(60, 110, 60, 60)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 18,
                      color: Color.fromARGB(160, 110, 60, 60)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'An invite code will be generated automatically. Share it with friends so they can request to join.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color.fromARGB(180, 70, 40, 20),
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}