import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../main.dart';
import '../user/signup_screen.dart';
import 'owner_bookings_screen.dart';
import 'manage_slots_screen.dart';
import 'cancel_booking_screen.dart';
import 'earnings_screen.dart';

class OwnerDashboard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Owner Dashboard", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Color(0xFF0033AA),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => ArrivalScreen()),
              );
            }
          },
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => SignupScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Welcome Header
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Color(0xFF0033AA),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Text(
                  "Welcome, Owner!",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  "Manage your EV charging station efficiently",
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
          SizedBox(height: 25),
          // Scrollable List of Containers
          Expanded(
            child: SingleChildScrollView(
              physics: BouncingScrollPhysics(), // Smooth scrolling effect
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildCard(context, "View Bookings", Icons.book_online, OwnerBookingsScreen()),
                  _buildCard(context, "Manage Slots", Icons.ev_station, ManageSlotsScreen()),
                  _buildCard(context, "Cancel Bookings", Icons.cancel, CancelBookingScreen()),
                  _buildCard(context, "Earnings", Icons.currency_rupee, EarningsScreen()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context, String title, IconData icon, Widget screen) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Card(
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        color: Colors.white,
        child: InkWell(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => screen)),
          child: Container(
            width: double.infinity, // Full width
            padding: EdgeInsets.symmetric(vertical: 30, horizontal: 16),
            child: Row(
              children: [
                Icon(icon, size: 50, color: Color(0xFF0033AA)), // Enlarged icon
                SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87),
                  ),
                ),
                Icon(Icons.arrow_forward_ios, color: Colors.grey), // Right arrow indicator
              ],
            ),
          ),
        ),
      ),
    );
  }
}
