import 'package:app/screens/book_log/book_log_screen.dart';
import 'package:app/screens/clubs/clubs_screen.dart';
import 'package:app/screens/events/events_screen.dart';
import 'package:app/screens/home_screen/home_screen.dart';
import 'package:app/screens/profile/profile_screen.dart';
import 'package:app/widgets/user_appbar.dart';
import 'package:flutter/material.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    BookLogScreen(),
    ClubsScreen(),
    EventsScreen(),
    ProfileScreen(),
  ];

  final List<String> _titles = const [
    'The Book was Better',
    'My Books',
    'My Clubs',
    'Events',
    'Profile',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: UserAppBar(title: _titles[_currentIndex]),
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color.fromARGB(255, 221, 209, 153),
        selectedItemColor: const Color.fromARGB(255, 110, 60, 60),
        unselectedItemColor: const Color.fromARGB(255, 140, 120, 90),
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book_outlined),
            activeIcon: Icon(Icons.menu_book),
            label: 'My Books',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.groups_outlined),
            activeIcon: Icon(Icons.groups),
            label: 'Clubs',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.event_outlined),
            activeIcon: Icon(Icons.event),
            label: 'Events',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
