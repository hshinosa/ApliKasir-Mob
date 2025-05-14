// screen/checkout/widgets/numpad_widget.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class NumpadWidget extends StatelessWidget {
  final Function(String) onKeyPressed;
  final VoidCallback onBackspacePressed;
  final VoidCallback? onClearPressed; // Opsional clear

  const NumpadWidget({
    super.key,
    required this.onKeyPressed,
    required this.onBackspacePressed,
    this.onClearPressed,
  });

  @override
  Widget build(BuildContext context) {
    final buttonStyle = TextButton.styleFrom(
      foregroundColor: Colors.black87,
      backgroundColor: Colors.grey.shade200,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      padding: const EdgeInsets.symmetric(vertical: 10), // Sesuaikan padding
      textStyle: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600),
    );

    final iconButtonStyle = IconButton.styleFrom(
      foregroundColor: Colors.black87,
      backgroundColor: Colors.grey.shade200,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.all(10), // Sesuaikan padding
    );

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics:
          const NeverScrollableScrollPhysics(), // Tidak perlu scroll internal
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      padding: const EdgeInsets.symmetric(
          horizontal: 50, vertical: 10), // Padding grid
      children: [
        // Baris 1
        TextButton(
            onPressed: () => onKeyPressed('1'),
            style: buttonStyle,
            child: const Text('1')),
        TextButton(
            onPressed: () => onKeyPressed('2'),
            style: buttonStyle,
            child: const Text('2')),
        TextButton(
            onPressed: () => onKeyPressed('3'),
            style: buttonStyle,
            child: const Text('3')),
        // Baris 2
        TextButton(
            onPressed: () => onKeyPressed('4'),
            style: buttonStyle,
            child: const Text('4')),
        TextButton(
            onPressed: () => onKeyPressed('5'),
            style: buttonStyle,
            child: const Text('5')),
        TextButton(
            onPressed: () => onKeyPressed('6'),
            style: buttonStyle,
            child: const Text('6')),
        // Baris 3
        TextButton(
            onPressed: () => onKeyPressed('7'),
            style: buttonStyle,
            child: const Text('7')),
        TextButton(
            onPressed: () => onKeyPressed('8'),
            style: buttonStyle,
            child: const Text('8')),
        TextButton(
            onPressed: () => onKeyPressed('9'),
            style: buttonStyle,
            child: const Text('9')),
        // Baris 4
        // Tombol Clear (Opsional)
        if (onClearPressed != null)
          IconButton(
              onPressed: onClearPressed,
              style: iconButtonStyle,
              icon: const Icon(Icons.clear_rounded, size: 22))
        else // Placeholder jika clear tidak ada
          Container(),
        TextButton(
            onPressed: () => onKeyPressed('0'),
            style: buttonStyle,
            child: const Text('0')),
        // Tombol Backspace
        IconButton(
            onPressed: onBackspacePressed,
            style: iconButtonStyle,
            icon: const Icon(Icons.backspace_outlined, size: 22)),
      ],
    );
  }
}
