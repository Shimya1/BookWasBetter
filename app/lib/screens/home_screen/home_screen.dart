import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app/models/appState.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color.fromARGB(255, 221, 209, 153),
            Color.fromARGB(255, 207, 178, 141),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 12),

            // Beta badge
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 110, 60, 60),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'BETA',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Welcome heading
            const Text(
              'Welcome to BookWasBetter',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color.fromARGB(255, 70, 40, 20),
              ),
            ),
            const SizedBox(height: 12),

            // Thank you message
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color.fromARGB(180, 255, 250, 235),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'Thank you for helping test BookWasBetter! Your feedback directly shapes the app. '
                'If you spot something broken or have an idea to make it better, let us know below — '
                'every report makes a difference.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Color.fromARGB(220, 70, 40, 20),
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Section label
            const Text(
              'SHARE FEEDBACK',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: Color.fromARGB(160, 70, 40, 20),
              ),
            ),
            const SizedBox(height: 10),

            // Bug report card
            _FeedbackCard(
              icon: Icons.bug_report_outlined,
              title: 'Report a Bug',
              subtitle: 'Something not working as expected?',
              type: 'bug',
            ),
            const SizedBox(height: 10),

            // Feature suggestion card
            _FeedbackCard(
              icon: Icons.lightbulb_outline,
              title: 'Suggest a Feature',
              subtitle: 'Got an idea to improve the app?',
              type: 'feature',
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String type;

  const _FeedbackCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showFeedbackSheet(context),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color.fromARGB(220, 255, 250, 235),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color.fromARGB(30, 110, 60, 60),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: const Color.fromARGB(255, 110, 60, 60), size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: Color.fromARGB(255, 70, 40, 20),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color.fromARGB(180, 110, 60, 60),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: Color.fromARGB(150, 110, 60, 60)),
          ],
        ),
      ),
    );
  }

  void _showFeedbackSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color.fromARGB(255, 250, 243, 220),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _FeedbackForm(type: type, title: title),
    );
  }
}

class _FeedbackForm extends StatefulWidget {
  final String type;
  final String title;
  const _FeedbackForm({required this.type, required this.title});

  @override
  State<_FeedbackForm> createState() => _FeedbackFormState();
}

class _FeedbackFormState extends State<_FeedbackForm> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final desc = _descController.text.trim();
    if (title.isEmpty || desc.isEmpty) return;

    setState(() => _isSubmitting = true);
    try {
      await context.read<StateModel>().submitFeedback(
            type: widget.type,
            title: title,
            description: desc,
          );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thanks for your feedback!'),
            backgroundColor: Color.fromARGB(255, 110, 60, 60),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Color.fromARGB(255, 70, 40, 20),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleController,
            decoration: _inputDecoration('Title'),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descController,
            decoration: _inputDecoration('Description'),
            minLines: 3,
            maxLines: 6,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _isSubmitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 110, 60, 60),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: _isSubmitting
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Submit',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color.fromARGB(120, 70, 40, 20)),
      filled: true,
      fillColor: Colors.white,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
            color: Color.fromARGB(80, 110, 60, 60), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
            color: Color.fromARGB(255, 110, 60, 60), width: 1.5),
      ),
    );
  }
}