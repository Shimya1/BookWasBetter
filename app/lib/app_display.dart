import 'package:app/screens/home_screen/app_home.dart';
import 'package:flutter/material.dart';

class AppDisplay extends StatefulWidget{
  AppDisplay({super.key});
  var state = 0;
  


  @override
  State<StatefulWidget> createState() {
  return _AppDisplay();
  }
}

class _AppDisplay extends State<AppDisplay>{
  

  @override
  Widget build(contect){
      return LaunchPage();
  }


}