import 'package:flutter/material.dart';

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isFullWidth;

  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isFullWidth = true,
  });

  @override
  Widget build(BuildContext context) {
    final btn = ElevatedButton(
      onPressed: onPressed,
      child: Text(label),
    );

    if (isFullWidth) {
      return SizedBox(width: double.infinity, child: btn);
    }
    return btn;
  }
}
