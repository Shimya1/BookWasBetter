import 'package:app/models/appState.dart';
import 'package:app/models/tag_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:provider/provider.dart';

class CreateTagScreen extends StatefulWidget {
  const CreateTagScreen({super.key});

  @override
  State<CreateTagScreen> createState() => _CreateTagScreenState();
}

class _CreateTagScreenState extends State<CreateTagScreen> {
  final _nameController = TextEditingController();
  Color _selectedColor = const Color(0xFF6E3C3C);
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Please enter a tag name.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final tag = Tag(name: name, color: _selectedColor.value);
      await context.read<StateModel>().createTag(tag);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = 'Failed to create tag. Please try again.');
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
          'Create Tag',
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
              'Tag name',
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
              decoration: InputDecoration(
                hintText: 'e.g. Foreshadowing',
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
              style: const TextStyle(color: Color.fromARGB(255, 70, 40, 20)),
            ),
            const SizedBox(height: 24),
            const Text(
              'Tag colour',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
                color: Color.fromARGB(160, 70, 40, 20),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: const Color.fromARGB(220, 255, 250, 235),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(16),
              child: ColorPicker(
                pickerColor: _selectedColor,
                onColorChanged: (color) =>
                    setState(() => _selectedColor = color),
                enableAlpha: false,
                labelTypes: const [],
                pickerAreaHeightPercent: 0.5,
              ),
            ),
            const SizedBox(height: 24),
            // Preview
            Row(
              children: [
                const Text(
                  'Preview: ',
                  style: TextStyle(
                    color: Color.fromARGB(180, 70, 40, 20),
                    fontSize: 13,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: _selectedColor.withAlpha(50),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _selectedColor),
                  ),
                  child: Text(
                    _nameController.text.isEmpty
                        ? 'Tag name'
                        : _nameController.text,
                    style: TextStyle(
                      color: _selectedColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _save,
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
                        'Create Tag',
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