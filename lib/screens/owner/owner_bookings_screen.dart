import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OwnerBookingsScreen extends StatelessWidget {
  final String ownerId = "owner_123"; // Replace with dynamic owner ID

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Station Bookings"),backgroundColor: Color(0xFF0033AA),
        foregroundColor: Colors.white,),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance
            .collection('bookings')
            .where('owner_id', isEqualTo: ownerId)
            .snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (!snapshot.hasData) return CircularProgressIndicator();
          return ListView(
            children: snapshot.data!.docs.map((doc) {
              return ListTile(
                title: Text("User: ${doc['user_email']}"),
                subtitle: Text("Slot: ${doc['slot_time']} | Status: ${doc['status']}"),
                trailing: Text(doc['status'], style: TextStyle(color: Colors.green)),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
