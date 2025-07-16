import 'package:clockin_app/widgets/watermark_page_route.dart';
import 'package:flutter/material.dart';

class WatermarkNavigatorObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);

    if (route is MaterialPageRoute) {
      // Menunda eksekusi dengan addPostFrameCallback untuk menghindari error _debugLocked
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final page = route.builder(route.navigator!.context);
        final watermarkRoute = WatermarkPageRoute(page: page);

        // Gantikan route saat ini dengan watermarkRoute
        Navigator.of(route.navigator!.context).pushReplacement(watermarkRoute);
      });
    }
  }
}
