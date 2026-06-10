import 'package:app/models/appState.dart';
import 'package:app/models/book_model.dart';
import 'package:app/models/book_view_model.dart';
import 'package:app/models/note_model.dart';
import 'package:app/models/tag_model.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app/screens/note/create_note_screen.dart';
import 'package:app/widgets/note_card.dart';

class BookDetailScreen extends StatefulWidget {
  final BookView book;

  const BookDetailScreen({super.key, required this.book});

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen> {
  late final Future<String?> _coverUrlFuture;

  @override
  void initState() {
    super.initState();
    _coverUrlFuture = FirebaseStorage.instance
        .ref('covers/${widget.book.googleBooksId}.jpg')
        .getDownloadURL()
        .catchError((_) => null);
  }

  // ─── Status colour helpers (shared with badge) ──────────────────────────────

  static Color statusBg(BookStatus s) => switch (s) {
        BookStatus.currentlyReading => const Color.fromARGB(255, 180, 230, 180),
        BookStatus.wantToRead => const Color.fromARGB(255, 200, 220, 245),
        BookStatus.finished => const Color.fromARGB(255, 230, 210, 170),
        BookStatus.abandoned => const Color.fromARGB(255, 230, 200, 200),
      };

  static Color statusFg(BookStatus s) => switch (s) {
        BookStatus.currentlyReading => const Color.fromARGB(255, 40, 100, 40),
        BookStatus.wantToRead => const Color.fromARGB(255, 30, 70, 140),
        BookStatus.finished => const Color.fromARGB(255, 100, 60, 10),
        BookStatus.abandoned => const Color.fromARGB(255, 130, 40, 40),
      };

  // ─── Status picker bottom sheet ─────────────────────────────────────────────

  void _showStatusPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color.fromARGB(255, 250, 243, 220),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Change status',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color.fromARGB(255, 70, 40, 20),
              ),
            ),
            const SizedBox(height: 12),
            ...BookStatus.values.map((s) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: statusBg(s),
                      shape: BoxShape.circle,
                      border: Border.all(color: statusFg(s), width: 1.5),
                    ),
                  ),
                  title: Text(
                    s.displayName,
                    style: TextStyle(
                      color: statusFg(s),
                      fontWeight: widget.book.status == s
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  trailing: widget.book.status == s
                      ? Icon(Icons.check, color: statusFg(s), size: 18)
                      : null,
                  onTap: () async {
                    Navigator.pop(ctx);
                    if (s != widget.book.status) {
                      await context
                          .read<StateModel>()
                          .updateBookStatus(widget.book.book.id, s);
                    }
                  },
                )),
          ],
        ),
      ),
    );
  }

  // ─── Chapter updater dialog ──────────────────────────────────────────────────

  void _showChapterDialog(BuildContext context) {
    final controller = TextEditingController(
      text: widget.book.currentChapter > 0
          ? widget.book.currentChapter.toString()
          : '',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color.fromARGB(255, 250, 243, 220),
        title: const Text(
          'Update chapter',
          style: TextStyle(
            color: Color.fromARGB(255, 70, 40, 20),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Current chapter',
            hintStyle: const TextStyle(color: Color.fromARGB(130, 70, 40, 20)),
            filled: true,
            fillColor: const Color.fromARGB(255, 240, 230, 200),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
          style: const TextStyle(color: Color.fromARGB(255, 70, 40, 20)),
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
              backgroundColor: const Color.fromARGB(255, 110, 60, 60),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              final chapter = int.tryParse(controller.text.trim());
              if (chapter != null && chapter >= 0) {
                Navigator.pop(ctx);
                await context
                    .read<StateModel>()
                    .updateBookChapter(widget.book.id, chapter);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // ─── Delete confirmation ─────────────────────────────────────────────────────

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color.fromARGB(255, 250, 243, 220),
        title: const Text(
          'Remove book',
          style: TextStyle(
            color: Color.fromARGB(255, 70, 40, 20),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Remove "${widget.book.title}" from your log? This will also delete all notes for this book.',
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
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await context
                  .read<StateModel>()
                  .deleteBook(widget.book.id, widget.book.googleBooksId);
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Listen for live updates to this specific book
    final liveBook = context.select<StateModel, BookView?>(
          (state) =>
              state.books.where((b) => b.id == widget.book.id).firstOrNull,
        ) ??
        widget.book;

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 240, 228, 185),
      body: CustomScrollView(
        slivers: [
          // ── App bar with cover ────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: const Color.fromARGB(255, 110, 60, 60),
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Blurred background from cover
                  FutureBuilder<String?>(
                    future: _coverUrlFuture,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData || snapshot.data == null) {
                        return const SizedBox.expand();
                      }
                      return Image.network(
                        snapshot.data!,
                        fit: BoxFit.cover,
                        color: Colors.black.withAlpha(120),
                        colorBlendMode: BlendMode.darken,
                      );
                    },
                  ),
                  // Cover + title row
                  Positioned(
                    bottom: 20,
                    left: 20,
                    right: 20,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Cover image
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: FutureBuilder<String?>(
                            future: _coverUrlFuture,
                            builder: (context, snapshot) {
                              if (snapshot.hasData && snapshot.data != null) {
                                return Image.network(
                                  snapshot.data!,
                                  width: 90,
                                  height: 135,
                                  fit: BoxFit.cover,
                                );
                              }
                              return Container(
                                width: 90,
                                height: 135,
                                color: const Color.fromARGB(255, 200, 180, 150),
                                child: const Icon(Icons.menu_book,
                                    size: 40,
                                    color: Color.fromARGB(120, 110, 60, 60)),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Title + author
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                liveBook.title,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  shadows: [
                                    Shadow(color: Colors.black54, blurRadius: 4)
                                  ],
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                liveBook.author,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.white70,
                                  shadows: [
                                    Shadow(color: Colors.black54, blurRadius: 4)
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: const [],
          ),

          // ── Body content ─────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Status row ───────────────────────────────────────────
                  _Section(
                    title: 'Status',
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => _showStatusPicker(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: statusBg(liveBook.status),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  liveBook.status.displayName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: statusFg(liveBook.status),
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Icon(Icons.expand_more,
                                    size: 18, color: statusFg(liveBook.status)),
                              ],
                            ),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => _showDeleteDialog(context),
                          icon: const Icon(Icons.delete_outline),
                          color: const Color.fromARGB(180, 130, 40, 40),
                          tooltip: 'Remove book',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

// ── Rating ───────────────────────────────────────────────────────
                  _Section(
                    title: 'My Rating',
                    child: _StarRating(
                      rating: liveBook.rating ?? 0,
                      onRatingChanged: (value) => context
                          .read<StateModel>()
                          .updateBookRating(liveBook.id, value),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Chapter progress (currently reading only) ────────────
                  if (liveBook.status == BookStatus.currentlyReading) ...[
                    _Section(
                      title: 'Progress',
                      child: GestureDetector(
                        onTap: () => _showChapterDialog(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color.fromARGB(220, 255, 250, 235),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.brown.withAlpha(30),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.bookmark,
                                  color: Color.fromARGB(255, 110, 60, 60),
                                  size: 20),
                              const SizedBox(width: 10),
                              Text(
                                liveBook.currentChapter > 0
                                    ? 'Chapter ${liveBook.currentChapter}'
                                    : 'Not started yet',
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: Color.fromARGB(255, 70, 40, 20),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const Spacer(),
                              const Text(
                                'Update',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color.fromARGB(180, 110, 60, 60),
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.chevron_right,
                                  size: 18,
                                  color: Color.fromARGB(180, 110, 60, 60)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ── Description ──────────────────────────────────────────
                  _Section(
                    title: 'About',
                    child: Text(
                      liveBook.description.isNotEmpty
                          ? liveBook.description
                          : 'No description available.',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color.fromARGB(220, 70, 40, 20),
                        height: 1.6,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Genre list ─────────────────────────────────────────────
                  if (liveBook.categories.isNotEmpty) ...[
                    _Section(
                      title: 'Genres',
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: liveBook.categories
                            .map((genre) => Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color:
                                        const Color.fromARGB(40, 110, 60, 60),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: const Color.fromARGB(
                                          100, 110, 60, 60),
                                    ),
                                  ),
                                  child: Text(
                                    genre,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color.fromARGB(200, 70, 40, 20),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ))
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ── Notes placeholder ────────────────────────────────────
                  // ── Notes ────────────────────────────────────────────────────────
                  _NotesSection(
                    googleBooksId: liveBook.googleBooksId,
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Section wrapper ──────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final Widget child;

  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: Color.fromARGB(160, 70, 40, 20),
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

// ─── Notes Section ────────────────────────────────────────────────────────────

class _NotesSection extends StatefulWidget {
  final String googleBooksId;
  const _NotesSection({required this.googleBooksId});

  @override
  State<_NotesSection> createState() => _NotesSectionState();
}

class _NotesSectionState extends State<_NotesSection> {
  Set<String> _activeTagFilters = {};

  @override
  Widget build(BuildContext context) {
    final state = context.watch<StateModel>();
    final userTags = state.profile?.tags ?? [];
    final allNotes = state.notes
        .where((n) => n.googleBooksId == widget.googleBooksId)
        .toList();

    // Filter by active tags — note must contain ALL selected tags
    final filtered = _activeTagFilters.isEmpty
        ? allNotes
        : allNotes
            .where(
                (n) => _activeTagFilters.every((id) => n.tagIds.contains(id)))
            .toList();

    return _Section(
      title: 'Notes',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Toolbar: New Note + Filter ─────────────────────────────
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CreateNoteScreen(
                      googleBooksId: widget.googleBooksId,
                    ),
                  ),
                ),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('New Note'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 110, 60, 60),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  textStyle: const TextStyle(fontSize: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const Spacer(),
              if (userTags.isNotEmpty)
                Stack(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.filter_list,
                          color: Color.fromARGB(200, 110, 60, 60)),
                      tooltip: 'Filter by tag',
                      onPressed: () => _showTagFilter(context, userTags),
                    ),
                    if (_activeTagFilters.isNotEmpty)
                      Positioned(
                        right: 6,
                        top: 6,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color.fromARGB(255, 110, 60, 60),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),

          const SizedBox(height: 12),

          // ── Active filter chips ────────────────────────────────────
          if (_activeTagFilters.isNotEmpty) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _activeTagFilters.map((id) {
                final tag = userTags.firstWhere((t) => t.id == id,
                    orElse: () => Tag(id: id, name: '?', color: 0xFF888888));
                final color = Color(tag.color);
                return GestureDetector(
                  onTap: () => setState(() => _activeTagFilters.remove(id)),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withAlpha(50),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: color),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          tag.name,
                          style: TextStyle(
                            fontSize: 12,
                            color: color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.close, size: 12, color: color),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
          ],

          // ── Notes list ─────────────────────────────────────────────
          if (filtered.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color.fromARGB(100, 255, 250, 235),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color.fromARGB(60, 110, 60, 60),
                ),
              ),
              child: Text(
                _activeTagFilters.isEmpty
                    ? 'No notes yet. Tap "New Note" to add one.'
                    : 'No notes match the selected filters.',
                style: const TextStyle(
                  color: Color.fromARGB(150, 70, 40, 20),
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          else
            ...filtered.map((note) => NoteCard(
                  note: note,
                  userTags: userTags,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CreateNoteScreen(
                        googleBooksId: widget.googleBooksId,
                        existingNote: note,
                      ),
                    ),
                  ),
                  onDelete: () => _confirmDelete(context, note),
                )),
        ],
      ),
    );
  }

  void _showTagFilter(BuildContext context, List<Tag> userTags) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color.fromARGB(255, 250, 243, 220),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Filter by tag',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color.fromARGB(255, 70, 40, 20),
                    ),
                  ),
                  const Spacer(),
                  if (_activeTagFilters.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        setState(() => _activeTagFilters.clear());
                        setSheetState(() {});
                      },
                      child: const Text(
                        'Clear all',
                        style:
                            TextStyle(color: Color.fromARGB(200, 110, 60, 60)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: userTags.map((tag) {
                  final selected = _activeTagFilters.contains(tag.id);
                  final color = Color(tag.color);
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        selected
                            ? _activeTagFilters.remove(tag.id)
                            : _activeTagFilters.add(tag.id);
                      });
                      setSheetState(() {});
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: selected
                            ? color.withAlpha(80)
                            : color.withAlpha(20),
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
                          fontWeight:
                              selected ? FontWeight.bold : FontWeight.normal,
                          color: color,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, Note note) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color.fromARGB(255, 250, 243, 220),
        title: const Text(
          'Delete note',
          style: TextStyle(
            color: Color.fromARGB(255, 70, 40, 20),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Delete "${note.title}"? This cannot be undone.',
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
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<StateModel>().deleteNote(note);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}


class _StarRating extends StatelessWidget {
  final double rating;
  final void Function(double) onRatingChanged;

  const _StarRating({
    required this.rating,
    required this.onRatingChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ...List.generate(5, (index) {
          return _Star(
            index: index,
            rating: rating,
            onRatingChanged: onRatingChanged,
          );
        }),
        const SizedBox(width: 8),
        Text(
          rating > 0 ? rating.toStringAsFixed(1) : '—',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color.fromARGB(200, 110, 60, 60),
          ),
        ),
      ],
    );
  }
}

class _Star extends StatelessWidget {
  final int index;
  final double rating;
  final void Function(double) onRatingChanged;

  const _Star({
    required this.index,
    required this.rating,
    required this.onRatingChanged,
  });

  @override
  Widget build(BuildContext context) {
    const filled = Color.fromARGB(255, 110, 60, 60);
    const empty = Color.fromARGB(60, 110, 60, 60);

    IconData icon;
    if (rating >= index + 1) {
      icon = Icons.star;
    } else if (rating >= index + 0.5) {
      icon = Icons.star_half;
    } else {
      icon = Icons.star_border;
    }

    return GestureDetector(
      onTapDown: (details) {
        final box = context.findRenderObject() as RenderBox;
        final localPos = box.globalToLocal(details.globalPosition);
        final isHalf = localPos.dx < box.size.width / 2;
        final newRating = isHalf ? index + 0.5 : index + 1.0;
        onRatingChanged(newRating);
      },
      child: Padding(
        padding: const EdgeInsets.only(right: 4),
        child: Icon(icon, color: rating > index * 1.0 || rating >= index + 0.5 ? filled : empty, size: 32),
      ),
    );
  }
}