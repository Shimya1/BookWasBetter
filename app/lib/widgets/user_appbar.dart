import 'package:app/models/appState.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class UserAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  const UserAppBar({super.key, this.title = 'The Book was Better'});

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
        title,
        style: GoogleFonts.tangerine(
          fontSize: 30,
          fontWeight: FontWeight.w600,
          color: const Color.fromARGB(255, 156, 100, 100),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Consumer<StateModel>(
            builder: (context, state, _) {
              final avatarUrl = state.profile?.avatarUrl ?? '';
              final displayName = state.profile?.displayName ?? '';
              return CircleAvatar(
                radius: 20,
                backgroundColor: const Color.fromARGB(255, 200, 180, 150),
                backgroundImage:
                    avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                child: avatarUrl.isEmpty
                    ? Text(
                        displayName.isNotEmpty
                            ? displayName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color.fromARGB(255, 110, 60, 60),
                        ),
                      )
                    : null,
              );
            },
          ),
        ),
      ],
    );
  }


  
}
