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
          title: Text("Admin Dashboard"),
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
        body: GridView.count(
          crossAxisCount: 2,
          padding: EdgeInsets.all(16),
          children: [
            _buildDashboardCard(context, "View Bookings", Icons.book_online, OwnerBookingsScreen()),
            _buildDashboardCard(context, "Manage Slots", Icons.ev_station, ManageSlotsScreen()),
            _buildDashboardCard(context, "Cancel Bookings", Icons.cancel, CancelBookingScreen()),
            _buildDashboardCard(context, "Earnings", Icons.attach_money, EarningsScreen()),
          ],
        ),
      );
    }

    Widget _buildDashboardCard(BuildContext context, String title, IconData icon, Widget screen) {
      return Card(
        margin: EdgeInsets.all(10),
        child: InkWell(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => screen)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: Colors.blue),
              SizedBox(height: 10),
              Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
    }
  }
