import 'package:flutter/material.dart';

class WatermarkOverlay extends StatelessWidget {
  final Widget child;

  const WatermarkOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child, // Konten asli screen
        Positioned(
          bottom: 200, // Mengatur watermark 20px dari bawah
          left: 0,
          right: 0,
          child: Opacity(
            opacity: 0.1, // Menentukan transparansi watermark
            child: Center(
              child: Text(
                '© 2025. Attendance App - My Name', // Watermark text
                style: TextStyle(
                  fontSize: 24, // Ukuran font watermark
                  color: Colors.black, // Warna teks watermark
                  fontWeight: FontWeight.bold, // Ketebalan font
                  letterSpacing: 2, // Jarak antar huruf
                  decoration: TextDecoration.none, // Menghilangkan garis bawah
                ),
                textAlign: TextAlign.center, // Teks terpusat
              ),
            ),
          ),
        ),
      ],
    );
  }
}
