
import 'package:app/widgets/user_appbar.dart';
import 'package:flutter/material.dart';

class LaunchPage extends StatelessWidget {
  const LaunchPage({super.key});

  @override
  Widget build(context) {
    return Scaffold(
      appBar: UserAppBar(), 
      body:Container(
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
      ),
    );
  }
}
