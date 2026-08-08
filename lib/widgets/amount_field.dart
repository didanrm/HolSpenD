import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/formatters.dart';

/// Re-formats digits as "1.400.000" while typing and keeps the caret at the end.
class ThousandsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue();

    // Guard against absurd input overflowing the int parse.
    final trimmed = digits.length > 15 ? digits.substring(0, 15) : digits;
    final text = formatPlain(int.parse(trimmed));

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class AmountField extends StatelessWidget {
  const AmountField({
    super.key,
    required this.controller,
    this.label = 'Nominal',
    this.autofocus = false,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final bool autofocus;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: TextInputType.number,
      inputFormatters: [ThousandsFormatter()],
      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        labelText: label,
        prefixText: 'Rp ',
        prefixStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
      ),
      validator: validator ??
          (value) {
            if (parseAmount(value ?? '') <= 0) return 'Nominal harus lebih dari 0';
            return null;
          },
    );
  }
}
