import 'package:colae_cut/services/sevice.dart';
import 'package:flutter/material.dart';

class BottonWidget extends StatelessWidget {
  final String label;
  final IconData icon;
  final Function() press;
  final TextStyle? style;
  final Color? color;

  const BottonWidget({
    super.key,
    required this.label,
    required this.icon,
    this.style,
    required this.press,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: color ?? mainColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      label: Text(label, style: style),
      onPressed: press,
      icon: Icon(icon, size: 20, color: Colors.white),
    );
  }
}
