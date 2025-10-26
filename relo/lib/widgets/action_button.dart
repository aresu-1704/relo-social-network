import 'package:flutter/material.dart';

// Widget nút với hiệu ứng scale khi nhấn
class ActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  State<ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<ActionButton>
    with SingleTickerProviderStateMixin {
  double _scale = 1.0;

  void _onTapDown(TapDownDetails details) {
    setState(() => _scale = 0.9);
  }

  void _onTapUp(TapUpDetails details) {
    setState(() => _scale = 1.0);
    widget.onTap();
  }

  void _onTapCancel() {
    setState(() => _scale = 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedScale(
            scale: _scale,
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOut,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: widget.color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(widget.icon, size: 28, color: widget.color),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.label,
            style: TextStyle(color: widget.color, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class VerticalActionButton extends StatelessWidget {
  final ActionButton button;

  const VerticalActionButton({required this.button});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: button.onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: button.color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(button.icon, color: button.color, size: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                button.label,
                style: TextStyle(
                  color: button.color,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
