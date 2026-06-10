import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

// Your deployed Cloud Function URL
const _functionUrl =
    'https://us-central1-thebookwasbetter-d4381.cloudfunctions.net/searchBooks';

class BookSearchResult {
  final String googleBooksId;
  final String title;
  final String author;
  final String coverUrl;
  final String description;
  final List<String> categories;

  BookSearchResult({
    required this.googleBooksId,
    required this.title,
    required this.author,
    required this.coverUrl,
    required this.description,
    this.categories = const [],
  });

  factory BookSearchResult.fromMap(Map<String, dynamic> map) {
    return BookSearchResult(
      googleBooksId: map['googleBooksId'] as String,
      title: map['title'] as String,
      author: map['author'] as String,
      coverUrl: map['coverUrl'] as String,
      description: map['description'] as String,
      categories: List<String>.from(map['categories'] ?? []),
    );
  }
}

class GoogleBooksService {
  Future<List<BookSearchResult>> search(String query) async {
    if (query.trim().isEmpty) return [];

    // Get the current user's ID token to authenticate the request
    final token =
        await FirebaseAuth.instance.currentUser?.getIdToken();
    if (token == null) throw Exception('Not authenticated.');

    final response = await http.post(
      Uri.parse(_functionUrl),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'query': query.trim()}),
    );

    if (response.statusCode != 200) {
      throw Exception('Search failed (${response.statusCode})');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final items = data['results'] as List<dynamic>;
    return items
        .map((item) =>
            BookSearchResult.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList();
  }
}
