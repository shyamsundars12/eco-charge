import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // ✅ For date formatting

class MyBookingsScreen extends StatefulWidget {
  @override
  _MyBookingsScreenState createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  final User? user = FirebaseAuth.instance.currentUser;

  /// ✅ Fetch only the confirmed bookings of the current user
  Stream<QuerySnapshot> _fetchBookings() {
    return FirebaseFirestore.instance
        .collection('bookings')
        .where('userId', isEqualTo: user?.uid)
        .where('status', isEqualTo: 'booked') // ✅ Only fetch confirmed bookings
        .orderBy('timestamp', descending: true) // ✅ Sort by latest first
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("My Bookings"),
        backgroundColor: Color(0xFF0033AA),
        leading: IconButton( // ✅ Back Button
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
            return Center(child: CircularProgressIndicator()); // ✅ Show Loader
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text("No bookings found", style: TextStyle(fontSize: 18)));
          }

          return ListView(
            padding: EdgeInsets.all(10),
            children: snapshot.data!.docs.map((doc) {
              Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

              // ✅ Format Date & Time
              String formattedDate = DateFormat('dd MMM yyyy').format(DateTime.parse(data['date']));
              String slotTime = data['slotTime']; // Time from Firestore

              return Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 3,
                margin: EdgeInsets.symmetric(vertical: 8),
                child: Container(
                  padding: EdgeInsets.all(16), // ✅ Added padding
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['stationName'], // ✅ Charging Station Name
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                          SizedBox(width: 5),
                          Text("Date: $formattedDate", style: TextStyle(fontSize: 16)),
                        ],
                      ),
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 16, color: Colors.grey),
                          SizedBox(width: 5),
                          Text("Time: $slotTime", style: TextStyle(fontSize: 16)),
                        ],
                      ),
                      Row(
                        children: [
                          Icon(Icons.electric_car, size: 16, color: Colors.grey),
                          SizedBox(width: 5),
                          Text("Vehicle: ${data['vehicleModel']}", style: TextStyle(fontSize: 16)),
                        ],
                      ),
                      Row(
                        children: [
                          Icon(Icons.battery_charging_full, size: 16, color: Colors.grey),
                          SizedBox(width: 5),
                          Text("Capacity: ${data['chargingCapacity']} kWh", style: TextStyle(fontSize: 16)),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        "Status: ${data['status'].toUpperCase()}",
                        style: TextStyle(fontSize: 16, color: Colors.green, fontWeight: FontWeight.bold),
                      ),
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
