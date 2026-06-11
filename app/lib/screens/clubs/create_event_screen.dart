import 'package:app/models/activity_model.dart';
import 'package:app/models/event_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CreateEventScreen extends StatefulWidget {
  final String clubId;
  const CreateEventScreen({super.key, required this.clubId});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  EventType _selectedType = EventType.meeting;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: DateTime(now.year + 2),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color.fromARGB(255, 110, 60, 60),
            onPrimary: Colors.white,
            surface: Color.fromARGB(255, 255, 250, 235),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color.fromARGB(255, 110, 60, 60),
            onPrimary: Colors.white,
            surface: Color.fromARGB(255, 255, 250, 235),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _save() async {
  if (_titleController.text.trim().isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please enter a title.')),
    );
    return;
  }
  if (_selectedDate == null || _selectedTime == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please select a date and time.')),
    );
    return;
  }

  setState(() => _saving = true);

  final uid = FirebaseAuth.instance.currentUser!.uid;

  final dateTime = DateTime(
    _selectedDate!.year,
    _selectedDate!.month,
    _selectedDate!.day,
    _selectedTime!.hour,
    _selectedTime!.minute,
  );

  final event = ClubEvent(
    title: _titleController.text.trim(),
    description: _descriptionController.text.trim(),
    type: _selectedType,
    dateTime: dateTime,
    createdBy: uid,
  );

  await FirebaseFirestore.instance
      .collection('clubs')
      .doc(widget.clubId)
      .collection('events')
      .doc(event.id)
      .set(event.toMap());

  // Write activity entry
  try {
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    final actorName =
        (userDoc.data()?['displayName'] as String? ?? '').isNotEmpty
            ? userDoc.data()!['displayName'] as String
            : 'A member';

    final entry = ActivityEntry(
      type: ActivityType.eventCreated,
      actorUid: uid,
      actorName: actorName,
      targetName: event.title,
    );

    await FirebaseFirestore.instance
        .collection('clubs')
        .doc(widget.clubId)
        .collection('activity')
        .doc(entry.id)
        .set(entry.toMap());
  } catch (e) {
    debugPrint('Activity write failed: $e');
  }

  if (mounted) Navigator.pop(context);
}

  String get _dateTimeLabel {
    if (_selectedDate == null && _selectedTime == null) return 'Select date & time';
    final date = _selectedDate == null
        ? 'No date'
        : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}';
    final time = _selectedTime == null ? 'No time' : _selectedTime!.format(context);
    return '$date at $time';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 240, 228, 185),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 110, 60, 60),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'New Event',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.check, color: Colors.white),
              onPressed: _save,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Title
          _FormCard(
            child: TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                labelStyle:
                    TextStyle(color: Color.fromARGB(180, 70, 40, 20)),
                border: InputBorder.none,
              ),
              style: const TextStyle(
                  color: Color.fromARGB(255, 70, 40, 20)),
            ),
          ),
          const SizedBox(height: 12),

          // Description
          _FormCard(
            child: TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description',
                labelStyle:
                    TextStyle(color: Color.fromARGB(180, 70, 40, 20)),
                border: InputBorder.none,
              ),
              style: const TextStyle(
                  color: Color.fromARGB(255, 70, 40, 20)),
            ),
          ),
          const SizedBox(height: 12),

          // Type selector
          _FormCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'EVENT TYPE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: Color.fromARGB(160, 70, 40, 20),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: EventType.values
                      .where((t) => t != EventType.bookSelection)
                      .map((type) => ChoiceChip(
                            label: Text(_typeLabel(type)),
                            selected: _selectedType == type,
                            onSelected: (_) =>
                                setState(() => _selectedType = type),
                            selectedColor:
                                const Color.fromARGB(255, 110, 60, 60),
                            labelStyle: TextStyle(
                              color: _selectedType == type
                                  ? Colors.white
                                  : const Color.fromARGB(200, 70, 40, 20),
                              fontSize: 12,
                            ),
                            backgroundColor:
                                const Color.fromARGB(40, 110, 60, 60),
                          ))
                      .toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Date & time
          _FormCard(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today,
                  color: Color.fromARGB(200, 110, 60, 60)),
              title: Text(
                _dateTimeLabel,
                style: const TextStyle(
                    color: Color.fromARGB(200, 70, 40, 20), fontSize: 14),
              ),
              onTap: () async {
                await _pickDate();
                if (_selectedDate != null) await _pickTime();
              },
            ),
          ),
        ],
      ),
    );
  }

  String _typeLabel(EventType type) => switch (type) {
        EventType.meeting => 'Meeting',
        EventType.bookSelection => 'Book Selection',
        EventType.misc => 'Misc',
      };
}

class _FormCard extends StatelessWidget {
  final Widget child;
  const _FormCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color.fromARGB(220, 255, 250, 235),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.brown.withAlpha(30),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}