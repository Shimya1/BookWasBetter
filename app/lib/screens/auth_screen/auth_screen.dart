import 'package:app/screens/auth_screen/auth_widget.dart';
import 'package:flutter/material.dart';

class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF3E4),
      body: Stack(
        children: [
          // Subtle decorative icons — low opacity background accents
          Positioned(
            top: 40,
            left: -10,
            child: Opacity(
              opacity: 0.06,
              child: Column(
                children: const [
                  Icon(Icons.menu_book, size: 90, color: Color(0xFF8B4513)),
                  SizedBox(height: 8),
                  Icon(Icons.book, size: 70, color: Color(0xFF8B4513)),
                  SizedBox(height: 8),
                  Icon(Icons.auto_stories, size: 80, color: Color(0xFF8B4513)),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 24,
            left: 20,
            child: Opacity(
              opacity: 0.08,
              child: const Icon(Icons.coffee, size: 52, color: Color(0xFF8B4513)),
            ),
          ),
          Positioned(
            bottom: 16,
            right: 16,
            child: Opacity(
              opacity: 0.08,
              child: const Icon(Icons.layers, size: 60, color: Color(0xFF8B4513)),
            ),
          ),
          // Main content — constrained for web, scrollable for mobile
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: AuthWidget(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}