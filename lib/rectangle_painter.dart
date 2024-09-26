import 'package:flutter/material.dart';

class RectanglePainter extends CustomPainter {
  // Constructor
  RectanglePainter();

  // Method to get the current time as a formatted string
  String getCurrentTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    // Define the rectangle's position in the center of the screen
    double left = (size.width / 2) - 100; // Center horizontally (200/2)
    double top = 50; // Center vertically (100/2)

    // Draw the rectangle
    canvas.drawRect(Rect.fromLTWH(left, top, 200, 100), paint);

    // Prepare to draw text
    final textStyle = TextStyle(
      color: Colors.white,
      fontSize: 24,
      fontWeight: FontWeight.bold,
    );

    final textSpan = TextSpan(
      text: getCurrentTime(), // Get current time directly from method
      style: textStyle,
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    // Layout the text
    textPainter.layout(minWidth: 0, maxWidth: 200);

    // Calculate the position to center the text inside the rectangle
    double textLeft = left + (200 - textPainter.width) / 2;
    double textTop = top + (100 - textPainter.height) / 2;

    // Draw the text
    textPainter.paint(canvas, Offset(textLeft, textTop));
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    // Repaint if needed; since we want to update every second,
    // we can return true to repaint whenever it is called.
    return true;
  }
}
