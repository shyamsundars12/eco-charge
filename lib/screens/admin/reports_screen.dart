import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ReportsScreen extends StatefulWidget {
  @override
  _ReportsScreenState createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  int totalBookings = 0;
  double totalRevenue = 0.0;
  Map<String, double> stationRevenue = {};

  @override
  void initState() {
    super.initState();
    fetchReportData();
  }

  void fetchReportData() async {
    DateTime now = DateTime.now();
    String currentMonth = DateFormat('yyyy-MM').format(now); // e.g., "2025-03"

    QuerySnapshot bookingsSnapshot = await FirebaseFirestore.instance.collection('bookings').get();

    int count = 0;
    double revenue = 0.0;
    Map<String, double> revenuePerStation = {};

    for (var doc in bookingsSnapshot.docs) {
      var data = doc.data() as Map<String, dynamic>;
      String? stationId = data['stationId'];
      String? bookingDate = data['date']; // "2025-03-23"
      double amountPaid = (data['amount'] ?? 0).toDouble();

      // ✅ Filter bookings only for the current month
      if (bookingDate != null && bookingDate.startsWith(currentMonth)) {
        count++;
        revenue += amountPaid;

        if (stationId != null) {
          revenuePerStation.update(stationId, (value) => value + amountPaid, ifAbsent: () => amountPaid);
        }
      }
    }

    // Fetch station names for better UI
    Map<String, String> stationNames = await fetchStationNames(revenuePerStation.keys.toList());

    setState(() {
      totalBookings = count;
      totalRevenue = revenue;
      stationRevenue = revenuePerStation.map((id, rev) => MapEntry(stationNames[id] ?? "Unknown Station", rev));
    });
  }

  Future<Map<String, String>> fetchStationNames(List<String> stationIds) async {
    Map<String, String> names = {};
    for (String id in stationIds) {
      DocumentSnapshot stationDoc = await FirebaseFirestore.instance.collection('ev_stations').doc(id).get();
      names[id] = stationDoc.exists ? (stationDoc['name'] ?? "Unknown Station") : "Unknown Station";
    }
    return names;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Monthly Reports"), backgroundColor: Color(0xFF0033AA), foregroundColor: Colors.white),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("📊 Total Bookings: $totalBookings", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            Text("💰 Total Revenue: ₹${totalRevenue.toStringAsFixed(2)}", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 20),
            Text("📍 Revenue by Station", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: stationRevenue.length,
                itemBuilder: (context, index) {
                  String stationName = stationRevenue.keys.elementAt(index);
                  double revenue = stationRevenue.values.elementAt(index);
                  return Card(
                    elevation: 3,
                    margin: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                    child: ListTile(
                      title: Text(stationName, style: TextStyle(fontWeight: FontWeight.bold)),
                      trailing: Text("₹${revenue.toStringAsFixed(2)}", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),

    );
  }
}
