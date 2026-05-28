import 'package:flutter/material.dart';

class MenuButton extends StatefulWidget {
  const MenuButton({super.key});

  @override
  State<MenuButton> createState() => _MenuButtonState();
}

class _MenuButtonState extends State<MenuButton> {
  final List<String> menuItems = [
    'Settings',
    'MyBookClub',
    'MeetingPlans',
  ];

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      builder: (context, controller, child) {
        return IconButton(
          icon: const Icon(Icons.more_horiz),
          onPressed: () {
            controller.isOpen ? controller.close() : controller.open();
          },
        );
      },
      menuChildren: menuItems
          .map((item) => MenuItemButton(
                onPressed: () {},
                child: Text(item),
              ))
          .toList(),
    );
  }
}