import 'package:app/screens/auth_screen/auth_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';


//import '../../models/state.dart';

class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Color.fromARGB(255, 221, 209, 153),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/images/title-image.png', width: 300),
            const SizedBox(height: 30),
            AuthWidget(),
          ],
        ),
      ),
    );
  }
}
