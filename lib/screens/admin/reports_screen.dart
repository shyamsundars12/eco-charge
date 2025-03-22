import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ReportsScreen extends StatefulWidget {
  @override
  _ReportsScreenState createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  int totalBookings = 0;
  double totalRevenue = 0.0;

  @override
  void initState() {
    super.initState();
    fetchReportData();
  }

  void fetchReportData() async {
    QuerySnapshot bookingsSnapshot = await FirebaseFirestore.instance.collection('bookings').get();

    int count = bookingsSnapshot.docs.length;
    double revenue = bookingsSnapshot.docs.fold(0, (sum, doc) => sum + (doc['amount_paid'] ?? 0.0));

    setState(() {
      totalBookings = count;
      totalRevenue = revenue;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Reports"),backgroundColor: Color(0xFF0033AA),
        foregroundColor: Colors.white,),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Total Bookings: $totalBookings", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            Text("Total Revenue: ₹${totalRevenue.toStringAsFixed(2)}",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),

          ],
        ),
      ),
    );
  }
}
