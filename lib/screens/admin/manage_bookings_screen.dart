import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ManageBookingsScreen extends StatefulWidget {
  @override
  _ManageBookingsScreenState createState() => _ManageBookingsScreenState();
}

class _ManageBookingsScreenState extends State<ManageBookingsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<Map<String, dynamic>>> fetchAllBookings() async {
    List<Map<String, dynamic>> allBookings = [];

    try {
      QuerySnapshot bookingSnapshot = await _firestore.collection('bookings').get();
      print("Total Bookings Found: ${bookingSnapshot.docs.length}");

      List<Future<void>> futures = [];

      for (var booking in bookingSnapshot.docs) {
        var data = booking.data() as Map<String, dynamic>;
        data['id'] = booking.id;

        // Fetch Station & User details in parallel
        futures.add(Future(() async {
          String stationId = data['stationId'] ?? "";
          String userId = data['userId'] ?? "";

          // Fetch Station Name
          if (stationId.isNotEmpty) {
            DocumentSnapshot stationDoc = await _firestore.collection('ev_stations').doc(stationId).get();
            data['station_name'] = stationDoc.exists ? stationDoc['name'] ?? "Unnamed Station" : "Unknown Station";
          } else {
            data['station_name'] = "Unknown Station";
          }

          // Fetch User Email
          if (userId.isNotEmpty) {
            DocumentSnapshot userDoc = await _firestore.collection('users').doc(userId).get();
            data['user_email'] = userDoc.exists ? userDoc['email'] ?? "No Email" : "Unknown User";
          } else {
            data['user_email'] = "Unknown User";
          }

          // ✅ Retrieve Booking Date from `date` field
          if (data.containsKey('date')) {
            data['formatted_date'] = data['date']; // Directly use stored string date
          } else {
            data['formatted_date'] = "Unknown Date";
          }

          // ✅ Fetch & format booking amount
          data['amount'] = data['amount'] != null ? "₹${data['amount']}" : "N/A";

          print("Booking: ${data['id']} - Station: ${data['station_name']} - Date: ${data['formatted_date']}");
          allBookings.add(data);
        }));
      }

      await Future.wait(futures);
    } catch (e) {
      print("Error fetching bookings: $e");
    }

    return allBookings;
  }

  void cancelBooking(String bookingId) async {
    await _firestore.collection('bookings').doc(bookingId).update({'status': 'cancelled'});
    setState(() {}); // Refresh UI
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Manage Bookings"),
        backgroundColor: Color(0xFF0033AA),
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder(
        future: fetchAllBookings(),
        builder: (context, AsyncSnapshot<List<Map<String, dynamic>>> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text("No bookings found."));
          }

          return ListView.builder(
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              var booking = snapshot.data![index];

              return Card(
                elevation: 4,
                margin: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("📍 Station: ${booking['station_name']}",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      SizedBox(height: 4),
                      Text("👤 User: ${booking['user_email']}",
                          style: TextStyle(fontSize: 14, color: Colors.black54)),
                      SizedBox(height: 4),
                      Text("⏰ Slot: ${booking['slotTime'] ?? 'N/A'}",
                          style: TextStyle(fontSize: 14, color: Colors.black87)),
                      SizedBox(height: 4),
                      Text("📅 Booking Date: ${booking['formatted_date']}",
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue)),
                      SizedBox(height: 4),
                      Text("💰 Amount: ${booking['amount']}",
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green)),
                      SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            booking['status'].toUpperCase(),
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: booking['status'] == 'cancelled' ? Colors.red : Colors.blue),
                          ),
                          if (booking['status'] != 'cancelled')
                            ElevatedButton(
                              onPressed: () => cancelBooking(booking['id']),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    child: Text("Cancel", style: TextStyle(color: Colors.white)),
                  )
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
