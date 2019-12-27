import 'package:flutter/material.dart';

class InkwellPainter extends CustomPainter {
  InkwellPainter(
      {@required this.color, @required this.alignment, @required this.scale})
      : _paint = Paint()
          ..color = color
          ..style = PaintingStyle.fill;
  final Color color;
  final Alignment alignment;
  final double scale;
  final Paint _paint;

  static Offset getStartPoint(Alignment alignment, Size size) {
    return Offset(size.width * (alignment.x + 1) / 2,
        size.height * (alignment.y + 1) / 2);
  }

  static Offset getEndPoint(Alignment alignment, Size size) {
    if (alignment.x < 0) {
      if (alignment.y < 0) {
        return Offset(size.width, size.height);
      } else {
        return Offset(size.width, 0);
      }
    } else {
      if (alignment.y < 0) {
        return Offset(0, size.height);
      } else {
        return Offset.zero;
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    // TODO: implement paint
    final Offset _endPoint = getEndPoint(alignment, size);
    final Offset _startPoint = getStartPoint(alignment, size);
    final double _radius = (_endPoint - _startPoint).distance * scale;
    canvas.drawCircle(_startPoint, _radius, _paint);
  }

  @override
  bool shouldRepaint(InkwellPainter oldDelegate) {
    // TODO: implement shouldRepaint
    return scale != oldDelegate.scale ||
        color != oldDelegate.color ||
        alignment != oldDelegate.alignment;
  }
}

class MultiInkwellPainter extends CustomPainter {
  const MultiInkwellPainter(
      {@required this.paints,
      @required this.alignments,
      @required this.scales,
      @required this.label});

  final List<Paint> paints;
  final List<Alignment> alignments;
  final List<double> scales;
  final label;

  static List<Paint> painterGenerator(List<Color> colors) {
    return List.generate(colors.length, (int i) {
      return Paint()
        ..color = colors[i]
        ..style = PaintingStyle.fill;
    });
  }

  static Offset getStartPoint(Alignment alignment, Size size) {
    return Offset(size.width * (alignment.x + 1) / 2,
        size.height * (alignment.y + 1) / 2);
  }

  static Offset getEndPoint(Alignment alignment, Size size) {
    if (alignment.x < 0) {
      if (alignment.y < 0) {
        return Offset(size.width, size.height);
      } else {
        return Offset(size.width, 0);
      }
    } else {
      if (alignment.y < 0) {
        return Offset(0, size.height);
      } else {
        return Offset.zero;
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    // TODO: implement paint
    for (int i = 0; i < paints.length; i++) {
      final Offset _endPoint = getEndPoint(alignments[i], size);
      final Offset _startPoint = getStartPoint(alignments[i], size);
      final double _radius = (_endPoint - _startPoint).distance * scales[i];
      canvas.drawCircle(_startPoint, _radius, paints[i]);
    }
  }

  @override
  bool shouldRepaint(MultiInkwellPainter oldDelegate) {
    // TODO: implement shouldRepaint
    return label != oldDelegate.label;
  }
}
