import 'package:flutter/material.dart';

class HelperFunctions {
  static String formatTimestamp(DateTime timestamp) {
    return "${timestamp.day}/${timestamp.month}/${timestamp.year} - ${timestamp.hour}:${timestamp.minute}";
  }

  static void showSnackbar(BuildContext context, String message, {Color color = Colors.green}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
      ),
    );
  }

  static String generateBookingId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  static String formatCurrency(double amount) {
    return "₹${amount.toStringAsFixed(2)}";
  }
}
