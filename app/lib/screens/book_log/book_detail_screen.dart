import 'package:app/models/appState.dart';
import 'package:app/models/book_model.dart';
import 'package:app/models/book_view_model.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
      text: widget.book.currentChapter > 0 ? widget.book.currentChapter.toString() : '',
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
            hintStyle:
                const TextStyle(color: Color.fromARGB(130, 70, 40, 20)),
            filled: true,
            fillColor: const Color.fromARGB(255, 240, 230, 200),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
          style:
              const TextStyle(color: Color.fromARGB(255, 70, 40, 20)),
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
          style:
              const TextStyle(color: Color.fromARGB(200, 70, 40, 20)),
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
              await context.read<StateModel>().deleteBook(widget.book.id, widget.book.googleBooksId);
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
    ) ?? widget.book;

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 240, 228, 185),
      body: CustomScrollView(
        slivers: [
          // ── App bar with cover ────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: const Color.fromARGB(255, 110, 60, 60),
            iconTheme:
                const IconThemeData(color: Colors.white),
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
                                    Shadow(
                                        color: Colors.black54,
                                        blurRadius: 4)
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
                                    Shadow(
                                        color: Colors.black54,
                                        blurRadius: 4)
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
                                size: 18,
                                color: statusFg(liveBook.status)),
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
                                  color:
                                      Color.fromARGB(255, 110, 60, 60),
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
                                  color: Color.fromARGB(
                                      180, 110, 60, 60),
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.chevron_right,
                                  size: 18,
                                  color: Color.fromARGB(
                                      180, 110, 60, 60)),
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

                  // ── Notes placeholder ────────────────────────────────────
                  _Section(
                    title: 'Notes',
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(100, 255, 250, 235),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color.fromARGB(60, 110, 60, 60),
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: const Text(
                        'Notes coming soon.',
                        style: TextStyle(
                          color: Color.fromARGB(150, 70, 40, 20),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
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
