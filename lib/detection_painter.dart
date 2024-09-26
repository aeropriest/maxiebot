import 'package:flutter/material.dart';

class DetectionPainter extends CustomPainter {
  final List<Rect> boxes;
  final List<String> labels;

  DetectionPainter(this.boxes, this.labels);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < boxes.length; i++) {
      canvas.drawRect(boxes[i], paint);
      TextPainter textPainter = TextPainter(
          text:
              TextSpan(text: labels[i], style: TextStyle(color: Colors.white)),
          textDirection: TextDirection.ltr);
      textPainter.layout();
      textPainter.paint(
          canvas, Offset(boxes[i].left, boxes[i].top - textPainter.height));
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
