import 'package:app/clickable/menue.dart';
import 'package:app/clickable/prof_image.dart';
import 'package:app/screens/auth_screen/auth_widget.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MyToolbar extends StatelessWidget implements PreferredSizeWidget {
  const MyToolbar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: Image.asset(
        'assets/images/parchmentBackground.jpg',
        fit: BoxFit.cover,
      ),
      leading: Padding(
        padding: const EdgeInsets.all(7.0),
        child: Image.asset(
          'assets/images/icon-alpha.png',
          fit: BoxFit.contain,
        ),
      ),
      title: Text(
        'The Book was Better',
        style: GoogleFonts.tangerine(
          fontSize: 30,
          fontWeight: FontWeight.w600,
          color: const Color.fromARGB(255, 156, 100, 100),
        ),
      ),
      actions: <Widget>[
      //Profile Icon 
      ProfileIcon(),
      // menue
      MenuButton(),
      //logout
      LogoutWidget(),
      ],
    );
  }
}
