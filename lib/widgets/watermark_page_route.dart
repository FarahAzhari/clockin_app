import 'package:clockin_app/widgets/watermark_overlay.dart';
import 'package:flutter/material.dart';

class WatermarkPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  WatermarkPageRoute({required this.page})
    : super(
        pageBuilder:
            (
              BuildContext context,
              Animation<double> animation,
              Animation<double> secondaryAnimation,
            ) {
              return WatermarkOverlay(child: page); // Bungkus dengan watermark
            },
        transitionsBuilder:
            (
              BuildContext context,
              Animation<double> animation,
              Animation<double> secondaryAnimation,
              Widget child,
            ) {
              return FadeTransition(
                opacity: animation,
                child: child,
              ); // Animasi transisi
            },
      );
}
