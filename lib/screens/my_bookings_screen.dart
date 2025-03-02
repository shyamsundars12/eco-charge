import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class MyBookingsScreen extends StatefulWidget {
  @override
  _MyBookingsScreenState createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  final User? user = FirebaseAuth.instance.currentUser;

  Stream<QuerySnapshot> _fetchBookings() {
    return FirebaseFirestore.instance
        .collection('bookings')
        .where('userId', isEqualTo: user?.uid)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("My Bookings"),
        backgroundColor: Color(0xFF0033AA),
        leading: IconButton(  // ✅ Back button
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _fetchBookings(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text("No bookings found"));
          }

          return ListView(
            padding: EdgeInsets.all(10),
            children: snapshot.data!.docs.map((doc) {
              Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
              return Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 3,
                margin: EdgeInsets.symmetric(vertical: 8),
                child: Container(
                  height: 150, // ✅ Increased height
                  padding: EdgeInsets.all(16), // ✅ Added padding
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['stationName'],
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                      ),
                      SizedBox(height: 8),
                      Text("Vehicle: ${data['vehicleModel']}", style: TextStyle(fontSize: 16)),
                      Text("Charging Capacity: ${data['chargingCapacity']} kWh", style: TextStyle(fontSize: 16)),
                      Text("Date: ${data['date']}", style: TextStyle(fontSize: 16)),
                      Text("Status: ${data['status']}", style: TextStyle(fontSize: 16)),
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
