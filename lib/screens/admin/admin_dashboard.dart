import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../main.dart';
import '../user/signup_screen.dart';
import 'add_owner_screen.dart';
import 'manage_stations_screen.dart';
import 'manage_bookings_screen.dart';
import 'reports_screen.dart';

class AdminDashboard extends StatelessWidget {
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
        children: [
          _buildCard(context, "Manage Owners", AddOwnerScreen()),
          _buildCard(context, "Manage Stations", ManageStationsScreen()),
          _buildCard(context, "Manage Bookings", ManageBookingsScreen()),
          _buildCard(context, "Reports", ReportsScreen()),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context, String title, Widget screen) {
    return Card(
      margin: EdgeInsets.all(10),
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => screen)),
        child: Center(child: Text(title, textAlign: TextAlign.center)),
      ),
    );
  }
}
