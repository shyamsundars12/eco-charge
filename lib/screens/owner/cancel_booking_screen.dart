import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CancelBookingScreen extends StatelessWidget {
  final String ownerId = "owner_123"; // Replace with dynamic owner ID

  void cancelBooking(String id) {
    FirebaseFirestore.instance.collection('bookings').doc(id).update({'status': 'Cancelled'});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Cancel Bookings"),backgroundColor: Color(0xFF0033AA),
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
              return Card(
                margin: EdgeInsets.all(8),
                child: ListTile(
                  title: Text("User: ${doc['user_email']}"),
                  subtitle: Text("Slot: ${doc['slot_time']}"),
                  trailing: doc['status'] == 'Active'
                      ? ElevatedButton(
                    onPressed: () => cancelBooking(doc.id),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    child: Text("Cancel", style: TextStyle(color: Colors.white)),
                  )
                      : Text(doc['status'], style: TextStyle(color: Colors.grey)),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
