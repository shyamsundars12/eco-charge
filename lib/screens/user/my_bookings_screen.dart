import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ecocharge/screens/user/map_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({Key? key}) : super(key: key);

  @override
  _MyBookingsScreenState createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Bookings'),
        backgroundColor: const Color(0xFF0033AA),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) =>  MapScreen()),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('bookings')
            .where('user_id', isEqualTo: _auth.currentUser?.uid)
            .orderBy('created_at', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.event_busy,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No bookings found',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var booking = snapshot.data!.docs[index].data() as Map<String, dynamic>;
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Booking #${snapshot.data!.docs[index].id.substring(0, 8)}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _getStatusColor(booking['status']).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              booking['status'].toString().toUpperCase(),
                              style: TextStyle(
                                color: _getStatusColor(booking['status']),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildInfoRow('Date', booking['date']),
                      _buildInfoRow('Time', booking['time']),
                      _buildInfoRow('Charging Point', booking['point_id']),
                      _buildInfoRow('Vehicle Number', booking['vehicle_number']),
                      _buildInfoRow('Vehicle Model', booking['vehicle_model']),
                      _buildInfoRow('Charging Capacity', '${booking['charging_capacity']} kWh'),
                      const Divider(height: 32),
                      _buildInfoRow(
                        'Total Amount',
                        '₹${(booking['total_amount'] ?? 0.0).toStringAsFixed(2)}',
                        isAmount: true,
                      ),
                      _buildInfoRow(
                        'Advance Paid',
                        '₹${(booking['advance_paid'] ?? 0.0).toStringAsFixed(2)}',
                        isAmount: true,
                      ),
                      _buildInfoRow(
                        'Remaining Amount',
                        '₹${(booking['remaining_amount'] ?? 0.0).toStringAsFixed(2)}',
                        isAmount: true,
                      ),
                      const SizedBox(height: 16),
                      if (booking['status'] == 'booked')
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => _showCancelConfirmation(snapshot.data!.docs[index].id),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Cancel Booking'),
                          ),
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

  Widget _buildInfoRow(String label, String value, {bool isAmount = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isAmount ? FontWeight.bold : FontWeight.normal,
              color: isAmount ? const Color(0xFF0033AA) : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'booked':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'completed':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Future<void> _showCancelConfirmation(String bookingId) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Booking'),
        content: const Text('Are you sure you want to cancel this booking?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _cancelBooking(bookingId);
            },
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelBooking(String bookingId) async {
    try {
      setState(() => _isLoading = true);
      print('Starting cancellation process for booking: $bookingId');

      // Get booking details
      DocumentSnapshot bookingDoc = await _firestore
          .collection('bookings')
          .doc(bookingId)
          .get();

      if (!bookingDoc.exists) {
        throw Exception('Booking not found');
      }

      Map<String, dynamic> booking = bookingDoc.data() as Map<String, dynamic>;
      print('Found booking details: ${booking.toString()}');

      // Get slot document
      DocumentSnapshot slotDoc = await _firestore
          .collection('charging_slots')
          .doc(booking['station_id'])
          .collection('slots')
          .doc(booking['slot_id'])
          .get();

      if (!slotDoc.exists) {
        throw Exception('Slot not found');
      }

      Map<String, dynamic> slotData = slotDoc.data() as Map<String, dynamic>;
      List<dynamic> chargingPoints = List.from(slotData['charging_points'] ?? []);
      print('Found slot with ${chargingPoints.length} charging points');

      // Find and update the charging point status
      bool pointFound = false;
      for (int i = 0; i < chargingPoints.length; i++) {
        print('Checking point ${chargingPoints[i]['id']} against ${booking['point_id']}');
        if (chargingPoints[i]['id'].toString() == booking['point_id']) {
          print('Found matching point, updating status');
          chargingPoints[i]['status'] = 'available';
          chargingPoints[i]['booked_by'] = null;
          chargingPoints[i]['pending_by'] = null;
          chargingPoints[i]['updated_at'] = DateTime.now().toIso8601String();
          pointFound = true;
          break;
        }
      }

      if (!pointFound) {
        throw Exception('Charging point not found');
      }

      // Update the slot with the modified charging points
      print('Updating slot with modified charging points');
      await _firestore
          .collection('charging_slots')
          .doc(booking['station_id'])
          .collection('slots')
          .doc(booking['slot_id'])
          .update({
        'charging_points': chargingPoints,
        'updated_at': FieldValue.serverTimestamp(),
      });

      // Update booking status
      print('Updating booking status to cancelled');
      await _firestore.collection('bookings').doc(bookingId).update({
        'status': 'cancelled',
        'updated_at': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Booking cancelled successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error in cancellation process: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cancelling booking: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
