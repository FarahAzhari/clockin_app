import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  final double height;
  final double width;
  const AppLogo({super.key, required this.height, required this.width});

  @override
  Widget build(BuildContext context) {
    return
    // Icon(Icons.access_alarm, size: size, color: Colors.white);
    Image.asset('assets/images/logo.png', height: height, width: width);
  }
}
