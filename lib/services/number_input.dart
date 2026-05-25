// FIXED: InputFormatter ที่ปรับ cursor ให้อยู่ท้ายเสมอ + handle deletion ดีขึ้น
import 'package:flutter/services.dart';

class NumberInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final String cleanNewText = newValue.text.replaceAll(RegExp(r'[^\d.]'), '');
    if (cleanNewText.isEmpty) {
      return newValue.copyWith(text: '');
    }
    if (cleanNewText.contains(RegExp(r'\.\d*\.\d*'))) {
      return oldValue;
    }
    final double? value = double.tryParse(cleanNewText);
    if (value == null) {
      return oldValue;
    }

    final String integerPart = value.toInt().toString();
    String formattedInteger = integerPart.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    String formatted;
    if (cleanNewText.contains('.')) {
      final String decimalPart = (value % 1 * 100).toInt().toString().padLeft(
            2,
            '0',
          );
      formatted = '$formattedInteger.$decimalPart';
    } else {
      formatted = formattedInteger;
    }
    final int newOffset = formatted.length;

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: newOffset), // ท้ายสุดเสมอ
    );
  }
}
