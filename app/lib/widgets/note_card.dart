import 'package:app/models/note_model.dart';
import 'package:app/models/tag_model.dart';
import 'package:flutter/material.dart';

class NoteCard extends StatelessWidget {
  final Note note;
  final List<Tag> userTags;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const NoteCard({
    super.key,
    required this.note,
    required this.userTags,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    // Resolve tag IDs to Tag objects
    final tags = userTags.where((t) => note.tagIds.contains(t.id)).toList();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: const Color.fromARGB(220, 255, 250, 235),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.brown.withAlpha(40),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top row: title + delete ──────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      note.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color.fromARGB(255, 70, 40, 20),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  GestureDetector(
                    onTap: onDelete,
                    child: const Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: Color.fromARGB(150, 130, 40, 40),
                    ),
                  ),
                ],
              ),

              // ── Chapter ──────────────────────────────────────────────
              if (note.chapter > 0) ...[
                const SizedBox(height: 4),
                Text(
                  'Chapter ${note.chapter}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color.fromARGB(150, 110, 60, 60),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],

              // ── Body preview ─────────────────────────────────────────
              if (note.body.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  note.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color.fromARGB(200, 70, 40, 20),
                    height: 1.4,
                  ),
                ),
              ],

              // ── Tags ─────────────────────────────────────────────────
              if (tags.isNotEmpty) ...[
                const SizedBox(height: 10),
                _TagRow(tags: tags),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TagRow extends StatelessWidget {
  final List<Tag> tags;
  const _TagRow({required this.tags});

  @override
  Widget build(BuildContext context) {
    const maxVisible = 3;
    final visible = tags.take(maxVisible).toList();
    final overflow = tags.length - maxVisible;

    return Row(
      children: [
        ...visible.map((tag) => Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _TagChip(tag: tag),
            )),
        if (overflow > 0)
          Text(
            '+$overflow more',
            style: const TextStyle(
              fontSize: 11,
              color: Color.fromARGB(150, 70, 40, 20),
            ),
          ),
      ],
    );
  }
}

class _TagChip extends StatelessWidget {
  final Tag tag;
  const _TagChip({required this.tag});

  @override
  Widget build(BuildContext context) {
    final color = Color(tag.color);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(50),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Text(
        tag.name,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}