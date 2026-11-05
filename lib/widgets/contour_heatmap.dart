import 'package:flutter/material.dart';
import '../models/geo_matrix.dart';

class ContourHeatmap extends StatelessWidget {
  final GeoMatrix matrix;

  const ContourHeatmap({super.key, required this.matrix});

  @override
  Widget build(BuildContext context) {
    if (matrix.sites.length < 2 || matrix.frequencies.length < 2) {
      return const Center(
        child: Text(
          "البيانات غير كافية لرسم الخريطة المقطعية (يلزم نقطتان وترددان على الأقل).",
          style: TextStyle(color: Colors.amberAccent, fontSize: 15),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(
            "Site (X-Axis: Points)  vs  Frequency (Y-Axis: Depth)",
            style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(54, 16, 20, 42),
            child: CustomPaint(
              painter: _BilinearContourPainter(matrix: matrix),
              child: const SizedBox.expand(),
            ),
          ),
        ),
        _buildColorLegend(),
      ],
    );
  }

  Widget _buildColorLegend() {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E222D),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Low Voltage (Water Potential)",
                  style: TextStyle(color: Colors.lightBlueAccent, fontSize: 11, fontWeight: FontWeight.bold)),
              Text("High Voltage (Dry Rock)",
                  style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            height: 14,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF0026FF),
                  Color(0xFF00E5FF),
                  Color(0xFF00E676),
                  Color(0xFFFFEA00),
                  Color(0xFFFF1744),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("${matrix.minVoltage.toStringAsFixed(1)} mV",
                  style: const TextStyle(color: Colors.white70, fontSize: 11)),
              Text("${((matrix.minVoltage + matrix.maxVoltage) / 2).toStringAsFixed(1)} mV",
                  style: const TextStyle(color: Colors.white70, fontSize: 11)),
              Text("${matrix.maxVoltage.toStringAsFixed(1)} mV",
                  style: const TextStyle(color: Colors.white70, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

class _BilinearContourPainter extends CustomPainter {
  final GeoMatrix matrix;

  _BilinearContourPainter({required this.matrix});

  @override
  void paint(Canvas canvas, Size size) {
    final int rows = matrix.frequencies.length;
    final int cols = matrix.sites.length;

    const double step = 3.0;
    final Paint cellPaint = Paint()..style = PaintingStyle.fill;

    for (double py = 0; py < size.height; py += step) {
      final double gy = (py / size.height) * (rows - 1);
      final int y0 = gy.floor().clamp(0, rows - 1);
      final int y1 = (y0 + 1).clamp(0, rows - 1);
      final double dy = gy - y0;

      for (double px = 0; px < size.width; px += step) {
        final double gx = (px / size.width) * (cols - 1);
        final int x0 = gx.floor().clamp(0, cols - 1);
        final int x1 = (x0 + 1).clamp(0, cols - 1);
        final double dx = gx - x0;

        final double q00 = matrix.zValues[y0][x0];
        final double q10 = matrix.zValues[y0][x1];
        final double q01 = matrix.zValues[y1][x0];
        final double q11 = matrix.zValues[y1][x1];

        final double r1 = q00 * (1.0 - dx) + q10 * dx;
        final double r2 = q01 * (1.0 - dx) + q11 * dx;
        final double interpolatedV = r1 * (1.0 - dy) + r2 * dy;

        cellPaint.color = _mapVoltageToColor(interpolatedV);
        canvas.drawRect(Rect.fromLTWH(px, py, step + 0.6, step + 0.6), cellPaint);
      }
    }

    _drawGridAndLabels(canvas, size, cols, rows);
  }

  Color _mapVoltageToColor(double v) {
    final double span = matrix.maxVoltage - matrix.minVoltage;
    final double t = span <= 0 ? 0.5 : ((v - matrix.minVoltage) / span).clamp(0.0, 1.0);

    const List<Color> stops = [
      Color(0xFF0026FF),
      Color(0xFF00E5FF),
      Color(0xFF00E676),
      Color(0xFFFFEA00),
      Color(0xFFFF1744),
    ];

    final double scaled = t * (stops.length - 1);
    final int index = scaled.floor();
    final double frac = scaled - index;

    if (index >= stops.length - 1) return stops.last;
    return Color.lerp(stops[index], stops[index + 1], frac)!;
  }

  void _drawGridAndLabels(Canvas canvas, Size size, int cols, int rows) {
    final Paint borderPaint = Paint()
      ..color = Colors.white54
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawRect(Offset.zero & size, borderPaint);

    const TextStyle labelStyle = TextStyle(color: Colors.white70, fontSize: 10);

    for (int c = 0; c < cols; c++) {
      final double x = (c / (cols - 1)) * size.width;
      final TextPainter tp = TextPainter(
        text: TextSpan(text: 'S${matrix.sites[c]}', style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, size.height + 8));
    }

    final int yStep = (rows / 7).ceil().clamp(1, rows);
    for (int r = 0; r < rows; r += yStep) {
      final double y = (r / (rows - 1)) * size.height;
      final TextPainter tp = TextPainter(
        text: TextSpan(text: '${matrix.frequencies[r].toInt()}Hz', style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(-tp.width - 6, y - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _BilinearContourPainter oldDelegate) {
    return oldDelegate.matrix != matrix;
  }
}