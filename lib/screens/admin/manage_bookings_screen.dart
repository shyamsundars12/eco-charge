import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ManageBookingsScreen extends StatelessWidget {
  final CollectionReference bookings = FirebaseFirestore.instance.collection('bookings');

  void cancelBooking(String id) {
    bookings.doc(id).update({'status': 'Cancelled'});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Manage Bookings")),
      body: StreamBuilder(
        stream: bookings.snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (!snapshot.hasData) return CircularProgressIndicator();
          return ListView(
            children: snapshot.data!.docs.map((doc) {
              return Card(
                margin: EdgeInsets.all(8),
                child: ListTile(
                  title: Text("User: ${doc['user_email']}"),
                  subtitle: Text("Station: ${doc['station_name']} | Slot: ${doc['slot_time']}"),
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
