import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class RotatingCog extends StatefulWidget {
  final SvgPicture icon;
  final bool isSpinning; // control whether it rotates or not
  final double size;
  final bool clockwise; // control rotation direction
  final int duration; // duration for one full rotation in seconds
  const RotatingCog({super.key ,required this.icon, this.isSpinning = true, this.clockwise = true, this.duration = 5, this.size = 100});

  @override
  _RotatingCogState createState() => _RotatingCogState();
}

class _RotatingCogState extends State<RotatingCog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration:  Duration(seconds: widget.duration), // duration for one full rotation
    );

    _rotation = Tween<double>(
      begin: 0,
      end: widget.clockwise ? 1 : -1, // 1 turn clockwise or counter-clockwise
    ).animate(_controller);

    if (widget.isSpinning) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(RotatingCog oldWidget) {
    super.didUpdateWidget(oldWidget);

    // handle direction change
    if (oldWidget.clockwise != widget.clockwise) {
      _rotation = Tween<double>(
        begin: 0,
        end: widget.clockwise ? 1 : -1,
      ).animate(_controller);
    }

    if (widget.isSpinning && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isSpinning && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _rotation,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: widget.icon,
      ),
    );
  }
}
