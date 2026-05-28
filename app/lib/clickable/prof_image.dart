import 'package:flutter/material.dart';

class ProfileIcon extends StatelessWidget{
  const ProfileIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
          color: Colors.transparent, 
          child: InkWell(
            onTap: () {
              // go to profile page
            },
            splashColor: const Color.fromARGB(255, 120, 161, 196).withAlpha(30),
            highlightColor: Colors.blue.withAlpha(10), 
            child: CircleAvatar(
              radius: 50.0,
              // instead of hard code, get image from profile.
              backgroundImage: AssetImage('assets/images/profile-example.jpg'),
            )
          ),
        );
  }
}