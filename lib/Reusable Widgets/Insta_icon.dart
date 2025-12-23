import 'package:flutter/material.dart';

class CustomInstagramShareButton extends StatelessWidget {
  final double size;
  final Color color;
  final VoidCallback onPressed;

  const CustomInstagramShareButton({
    Key? key,
    this.size = 24.0,
    this.color = Colors.white,
    required this.onPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      child: Container(
        width: size,
        height: size,
        child: CustomPaint(
          painter: InstagramShareIconPainter(color: color),
        ),
      ),
    );
  }
}

class InstagramShareIconPainter extends CustomPainter {
  final Color color;

  InstagramShareIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final Path path = Path();

    // Drawing a paper airplane shape
    path.moveTo(0, size.height * 0.5);
    path.lineTo(size.width * 0.7, size.height * 0.5);
    path.lineTo(size.width, size.height * 0.2);
    path.lineTo(0, size.height * 0.5);
    path.lineTo(size.width * 0.7, size.height * 0.5);
    path.lineTo(size.width * 0.4, size.height * 0.8);
    path.lineTo(size.width * 0.7, size.height * 0.5);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
