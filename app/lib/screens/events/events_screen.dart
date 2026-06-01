import 'package:flutter/material.dart';

class EventsScreen extends StatelessWidget {
  const EventsScreen({super.key});

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
      child: const Center(
        child: Text(
          'Events',
          style: TextStyle(fontSize: 24, color: Color.fromARGB(255, 110, 60, 60)),
        ),
      ),
    );
  }
}
