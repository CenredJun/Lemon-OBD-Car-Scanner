import 'dart:math' as math;

import 'package:flutter/material.dart';

class GaugeWidget extends StatelessWidget {
  final String label;
  final String unit;
  final double value;
  final double minValue;
  final double maxValue;
  final double recordedMin;
  final double recordedMax;
  final bool hasData;

  const GaugeWidget({
    super.key,
    required this.label,
    required this.unit,
    required this.value,
    required this.minValue,
    required this.maxValue,
    required this.recordedMin,
    required this.recordedMax,
    required this.hasData,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF222222),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF333333)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: AspectRatio(
              aspectRatio: 1,
              child: CustomPaint(
                painter: _GaugePainter(
                  value: hasData ? value : minValue,
                  minValue: minValue,
                  maxValue: maxValue,
                  hasData: hasData,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        hasData ? _formatValue(value) : '--',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        unit,
                        style: const TextStyle(
                          color: Color(0xFFFF8C00),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _miniStat('MIN', hasData ? _formatValue(recordedMin) : '--'),
              _miniStat('MAX', hasData ? _formatValue(recordedMax) : '--'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 10,
            letterSpacing: 1,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  String _formatValue(double v) {
    if (v.abs() >= 1000) return v.toStringAsFixed(0);
    if (v.abs() >= 100) return v.toStringAsFixed(0);
    return v.toStringAsFixed(1);
  }
}

class _GaugePainter extends CustomPainter {
  final double value;
  final double minValue;
  final double maxValue;
  final bool hasData;

  _GaugePainter({
    required this.value,
    required this.minValue,
    required this.maxValue,
    required this.hasData,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 8;

    const startAngle = math.pi * 0.75;
    const sweepTotal = math.pi * 1.5;

    final bgPaint = Paint()
      ..color = const Color(0xFF2C2C2C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepTotal,
      false,
      bgPaint,
    );

    if (hasData && maxValue > minValue) {
      final t = ((value - minValue) / (maxValue - minValue))
          .clamp(0.0, 1.0);
      final fgPaint = Paint()
        ..shader = const SweepGradient(
          colors: [
            Color(0xFFFF8C00),
            Color(0xFFFFB347),
            Color(0xFFFF4500),
          ],
        ).createShader(
            Rect.fromCircle(center: center, radius: radius))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepTotal * t,
        false,
        fgPaint,
      );
    }

    // Tick marks
    final tickPaint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1.5;
    const ticks = 10;
    for (int i = 0; i <= ticks; i++) {
      final tt = i / ticks;
      final a = startAngle + sweepTotal * tt;
      final outer = Offset(
        center.dx + math.cos(a) * (radius - 14),
        center.dy + math.sin(a) * (radius - 14),
      );
      final inner = Offset(
        center.dx + math.cos(a) * (radius - 22),
        center.dy + math.sin(a) * (radius - 22),
      );
      canvas.drawLine(inner, outer, tickPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) {
    return old.value != value ||
        old.hasData != hasData ||
        old.minValue != minValue ||
        old.maxValue != maxValue;
  }
}
