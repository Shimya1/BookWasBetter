import 'package:app/models/appState.dart';
import 'package:app/models/club_model.dart';
import 'package:app/models/note_model.dart';
import 'package:app/models/tag_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app/screens/tag/create_tag_screen.dart';

class CreateNoteScreen extends StatefulWidget {
  final String googleBooksId;
  final Note? existingNote;

  const CreateNoteScreen({
    super.key,
    required this.googleBooksId,
    this.existingNote,
  });

  @override
  State<CreateNoteScreen> createState() => _CreateNoteScreenState();
}

class _CreateNoteScreenState extends State<CreateNoteScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  late final TextEditingController _chapterController;

  late bool _isPublic;
  late bool _selectOwnClubs;
  late List<String> _selectedTagIds;
  late List<String> _selectedClubIds;

  bool _isLoading = false;
  String? _error;

  bool get _isEditing => widget.existingNote != null;

  @override
  void initState() {
    super.initState();
    final note = widget.existingNote;
    _titleController = TextEditingController(text: note?.title ?? '');
    _bodyController = TextEditingController(text: note?.body ?? '');
    _chapterController = TextEditingController(
      text: note != null && note.chapter > 0 ? note.chapter.toString() : '',
    );
    _isPublic = note?.public ?? false;
    _selectedTagIds = List.from(note?.tagIds ?? []);
    _selectedClubIds = List.from(note?.clubs ?? []);
    _selectOwnClubs = _selectedClubIds.isNotEmpty;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _chapterController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    final chapterText = _chapterController.text.trim();

    if (title.isEmpty) {
      setState(() => _error = 'Please enter a title.');
      return;
    }

    if (chapterText.isNotEmpty && int.tryParse(chapterText) == null) {
      setState(() => _error = 'Chapter must be a number.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final chapter = int.tryParse(_chapterController.text.trim()) ?? 0;

      // If public but "all clubs" selected, clubs list is empty
      final clubs = _isPublic && _selectOwnClubs ? _selectedClubIds : [];

      if (_isEditing) {
        final updated = widget.existingNote!.copyWith(
          title: title,
          body: body,
          chapter: chapter,
          public: _isPublic,
          clubs: List<String>.from(clubs),
          tagIds: _selectedTagIds,
        );
        await context.read<StateModel>().updateNote(updated);
      } else {
        final note = Note(
          userId: uid,
          googleBooksId: widget.googleBooksId,
          title: title,
          body: body,
          chapter: chapter,
          public: _isPublic,
          clubs: List<String>.from(clubs),
          tagIds: _selectedTagIds,
        );
        await context.read<StateModel>().addNote(note);
      }

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = 'Failed to save note. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<StateModel>();
    final userTags = state.profile?.tags ?? [];
    final userClubs = state.clubs;

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 221, 209, 153),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 207, 178, 141),
        elevation: 0,
        title: Text(
          _isEditing ? 'Edit Note' : 'New Note',
          style: const TextStyle(
            color: Color.fromARGB(255, 70, 40, 20),
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: const IconThemeData(
          color: Color.fromARGB(255, 110, 60, 60),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _save,
            child: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color.fromARGB(255, 110, 60, 60),
                    ),
                  )
                : const Text(
                    'Save',
                    style: TextStyle(
                      color: Color.fromARGB(255, 110, 60, 60),
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Error ──────────────────────────────────────────────────────
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color.fromARGB(50, 170, 40, 40),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _error!,
                style: const TextStyle(color: Color.fromARGB(255, 130, 40, 40)),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── Title ──────────────────────────────────────────────────────
          _Label('Title'),
          const SizedBox(height: 8),
          _Field(
            controller: _titleController,
            hint: 'Note title',
          ),
          const SizedBox(height: 20),

          // ── Chapter ────────────────────────────────────────────────────
          _Label('Chapter'),
          const SizedBox(height: 8),
          _Field(
            controller: _chapterController,
            hint: 'e.g. 12',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 20),

          // ── Body ───────────────────────────────────────────────────────
          _Label('Note'),
          const SizedBox(height: 8),
          _Field(
            controller: _bodyController,
            hint: 'Write your note here...',
            maxLines: 8,
          ),
          const SizedBox(height: 20),

          // ── Tags ───────────────────────────────────────────────────────
          _Label('Tags'),
          const SizedBox(height: 8),
          _TagSelector(
            userTags: userTags,
            selectedTagIds: _selectedTagIds,
            onToggle: (id) => setState(() {
              _selectedTagIds.contains(id)
                  ? _selectedTagIds.remove(id)
                  : _selectedTagIds.add(id);
            }),
            onCreateTag: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const CreateTagScreen(),
              ), 
            ),
            onDeleteTag: (tag) => _confirmDeleteTag(context, tag),
          ),
          const SizedBox(height: 20),

          // ── Visibility ─────────────────────────────────────────────────
          _Label('Visibility'),
          const SizedBox(height: 8),
          _VisibilitySection(
            isPublic: _isPublic,
            selectOwnClubs: _selectOwnClubs,
            selectedClubIds: _selectedClubIds,
            userClubs: userClubs.toList(),
            onPublicChanged: (val) => setState(() {
              _isPublic = val;
              if (!val) {
                _selectOwnClubs = false;
                _selectedClubIds.clear();
              }
            }),
            onSelectOwnChanged: (val) => setState(() {
              _selectOwnClubs = val;
              if (!val) _selectedClubIds.clear();
            }),
            onClubToggle: (id) => setState(() {
              _selectedClubIds.contains(id)
                  ? _selectedClubIds.remove(id)
                  : _selectedClubIds.add(id);
            }),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ─── Label ────────────────────────────────────────────────────────────────────

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.1,
        color: Color.fromARGB(160, 70, 40, 20),
      ),
    );
  }
}

// ─── Field ────────────────────────────────────────────────────────────────────

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final TextInputType keyboardType;

  const _Field({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color.fromARGB(120, 70, 40, 20)),
        filled: true,
        fillColor: const Color.fromARGB(220, 255, 250, 235),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      style: const TextStyle(color: Color.fromARGB(255, 70, 40, 20)),
    );
  }
}

// ─── Tag selector ─────────────────────────────────────────────────────────────

class _TagSelector extends StatelessWidget {
  final List<Tag> userTags;
  final List<String> selectedTagIds;
  final void Function(String id) onToggle;
  final VoidCallback onCreateTag;
  final void Function(Tag tag) onDeleteTag;

  const _TagSelector({
    required this.userTags,
    required this.selectedTagIds,
    required this.onToggle,
    required this.onCreateTag,
    required this.onDeleteTag,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ...userTags.map((tag) {
          final selected = selectedTagIds.contains(tag.id);
          final color = Color(tag.color);
          return GestureDetector(
            onTap: () => onToggle(tag.id),
            onLongPress: () => onDeleteTag(tag),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? color.withAlpha(80) : color.withAlpha(20),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: color,
                  width: selected ? 2 : 1,
                ),
              ),
              child: Text(
                tag.name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  color: color,
                ),
              ),
            ),
          );
        }),

        // Create tag button
        GestureDetector(
          onTap: onCreateTag,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color.fromARGB(20, 110, 60, 60),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color.fromARGB(150, 110, 60, 60),
                style: BorderStyle.solid,
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add,
                    size: 14, color: Color.fromARGB(200, 110, 60, 60)),
                SizedBox(width: 4),
                Text(
                  'Create tag',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color.fromARGB(200, 110, 60, 60),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Visibility section ───────────────────────────────────────────────────────

class _VisibilitySection extends StatelessWidget {
  final bool isPublic;
  final bool selectOwnClubs;
  final List<String> selectedClubIds;
  final List<Club> userClubs;
  final void Function(bool) onPublicChanged;
  final void Function(bool) onSelectOwnChanged;
  final void Function(String) onClubToggle;

  const _VisibilitySection({
    required this.isPublic,
    required this.selectOwnClubs,
    required this.selectedClubIds,
    required this.userClubs,
    required this.onPublicChanged,
    required this.onSelectOwnChanged,
    required this.onClubToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color.fromARGB(220, 255, 250, 235),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Public toggle
          SwitchListTile(
            value: isPublic,
            onChanged: onPublicChanged,
            title: const Text(
              'Share with clubs',
              style: TextStyle(
                color: Color.fromARGB(255, 70, 40, 20),
                fontWeight: FontWeight.w500,
              ),
            ),
            activeColor: const Color.fromARGB(255, 110, 60, 60),
          ),

          // Who can view
          if (isPublic) ...[
            const Divider(height: 1, color: Color.fromARGB(40, 110, 60, 60)),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'WHO CAN VIEW',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                    color: const Color.fromARGB(160, 70, 40, 20),
                  ),
                ),
              ),
            ),
            RadioListTile<bool>(
              value: false,
              groupValue: selectOwnClubs,
              onChanged: (val) => onSelectOwnChanged(false),
              title: const Text(
                'All my clubs',
                style: TextStyle(color: Color.fromARGB(255, 70, 40, 20)),
              ),
              activeColor: const Color.fromARGB(255, 110, 60, 60),
            ),
            RadioListTile<bool>(
              value: true,
              groupValue: selectOwnClubs,
              onChanged: (val) => onSelectOwnChanged(true),
              title: const Text(
                'Select my own',
                style: TextStyle(color: Color.fromARGB(255, 70, 40, 20)),
              ),
              activeColor: const Color.fromARGB(255, 110, 60, 60),
            ),

            // Club checkboxes
            if (selectOwnClubs && userClubs.isNotEmpty) ...[
              const Divider(height: 1, color: Color.fromARGB(40, 110, 60, 60)),
              ...userClubs.map((club) => CheckboxListTile(
                    value: selectedClubIds.contains(club.id),
                    onChanged: (_) => onClubToggle(club.id),
                    title: Text(
                      club.name,
                      style: const TextStyle(
                          color: Color.fromARGB(255, 70, 40, 20)),
                    ),
                    activeColor: const Color.fromARGB(255, 110, 60, 60),
                    checkColor: Colors.white,
                  )),
            ],
          ],
        ],
      ),
    );
  }
}

// ─── Delete tag confirmation ───────────────────────────────────────────────
void _confirmDeleteTag(BuildContext context, Tag tag) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color.fromARGB(255, 250, 243, 220),
      title: const Text(
        'Delete tag',
        style: TextStyle(
          color: Color.fromARGB(255, 70, 40, 20),
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Text(
        'Delete "${tag.name}"? This will also remove it from any existing notes.',
        style: const TextStyle(color: Color.fromARGB(200, 70, 40, 20)),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text(
            'Cancel',
            style: TextStyle(color: Color.fromARGB(180, 70, 40, 20)),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color.fromARGB(255, 170, 40, 40),
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () async {
            Navigator.pop(ctx);
            await context.read<StateModel>().deleteTag(tag.id);
          },
          child: const Text('Delete'),
        ),
      ],
    ),
  );
}
