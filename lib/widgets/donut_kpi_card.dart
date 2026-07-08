import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../app_theme.dart';

class DonutMetaWidget extends StatelessWidget {
  final double percentual;
  final Color cor;

  const DonutMetaWidget({super.key, required this.percentual, required this.cor});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 110, height: 110,
      child: CustomPaint(
        painter: _DonutPainter(
          percentual: (percentual / 100).clamp(0.0, 1.0),
          cor: cor, backgroundColor: AppTheme.border, stroke: 12),
        child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('${percentual.toStringAsFixed(0)}%', style: TextStyle(
              fontSize: 24, fontWeight: FontWeight.w800,
              color: cor, fontFamily: 'Inter', height: 1)),
          Text('DA META', style: TextStyle(
              fontSize: 9, fontWeight: FontWeight.w700,
              color: cor.withOpacity(0.7), letterSpacing: 1, fontFamily: 'Inter')),
        ])),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final double percentual;
  final Color cor;
  final Color backgroundColor;
  final double stroke;

  _DonutPainter({required this.percentual, required this.cor,
      required this.backgroundColor, required this.stroke});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - stroke;
    canvas.drawCircle(center, radius, Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke);
    if (percentual > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2, 2 * math.pi * percentual, false,
        Paint()
          ..color = cor
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.percentual != percentual || old.cor != cor;
}
