import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EarningsScreen extends StatefulWidget {
  @override
  _EarningsScreenState createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  double totalEarnings = 0.0;
  final String ownerId = "owner_123"; // Replace with dynamic owner ID

  @override
  void initState() {
    super.initState();
    fetchEarnings();
  }

  void fetchEarnings() async {
    QuerySnapshot bookingsSnapshot = await FirebaseFirestore.instance
        .collection('bookings')
        .where('owner_id', isEqualTo: ownerId)
        .where('status', isEqualTo: 'Completed')
        .get();

    double earnings = bookingsSnapshot.docs.fold(0, (sum, doc) => sum + (doc['amount_paid'] ?? 0.0));

    setState(() {
      totalEarnings = earnings;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Earnings"),backgroundColor: Color(0xFF0033AA),
        foregroundColor: Colors.white,),
      body: Center(
        child: Text(
          "Total Earnings: ₹${totalEarnings.toStringAsFixed(2)}",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
