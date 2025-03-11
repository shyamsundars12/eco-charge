import 'package:flutter/material.dart';

class SlotCard extends StatelessWidget {
  final String time;
  final String status;
  final VoidCallback onTap;

  const SlotCard({
    Key? key,
    required this.time,
    required this.status,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: ListTile(
        title: Text(
          time,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text("Status: $status"),
        trailing: status == "available"
            ? ElevatedButton(
          onPressed: onTap,
          child: Text("Book Now"),
        )
            : Text("Unavailable", style: TextStyle(color: Colors.red)),
      ),
    );
  }
}
