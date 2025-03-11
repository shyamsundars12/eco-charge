import 'package:flutter/material.dart';

class BookingCard extends StatelessWidget {
  final String stationName;
  final String slotTime;
  final String status;
  final VoidCallback onCancel;

  const BookingCard({
    Key? key,
    required this.stationName,
    required this.slotTime,
    required this.status,
    required this.onCancel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: ListTile(
        title: Text(
          stationName,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text("Slot Time: $slotTime\nStatus: $status"),
        trailing: status == "Confirmed"
            ? ElevatedButton(
          onPressed: onCancel,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: Text("Cancel"),
        )
            : null,
      ),
    );
  }
}
