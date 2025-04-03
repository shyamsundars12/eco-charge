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
  bool _isLoading = true;
  List<Map<String, dynamic>> _bookings = [];
  Map<String, String> _stationNames = {};

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    try {
      setState(() => _isLoading = true);
      final user = _auth.currentUser;
      if (user == null) return;
      final bookingsSnapshot = await _firestore
          .collection('bookings')
          .where('userId', isEqualTo: user.uid)
          .orderBy('timestamp', descending: true)
          .get();
      final stationIds = bookingsSnapshot.docs
          .map((doc) => doc.data()['stationId'] as String)
          .toSet();
      final stationsSnapshot = await Future.wait(
        stationIds.map((id) => _firestore.collection('ev_stations').doc(id).get()),
      );
      final stationNames = {
        for (var doc in stationsSnapshot)
          doc.id: doc.data()?['name'] as String? ?? 'Unknown Station'
      };
      final bookings = bookingsSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'station_id': data['stationId'],
          'station_name': stationNames[data['stationId']] ?? 'Unknown Station',
          'vehicle_number': data['vehicleNumber'] ?? 'N/A',
          'vehicle_model': data['vehicleModel'] ?? 'N/A',
          'charging_capacity': data['chargingCapacity'] ?? 'N/A',
          'amount': (data['amount'] as num?)?.toDouble() ?? 0.0,
          'status': data['status'] ?? 'unknown',
          'date': data['date'] ?? 'N/A',
          'time': data['slotTime'] ?? 'N/A',
          'created_at': data['timestamp'] as Timestamp?,
          'payment_status': data['paymentStatus'] ?? 'unknown',
          'payment_id': data['paymentId'] ?? 'N/A',
        };
      }).toList();

      setState(() {
        _bookings = bookings;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading bookings: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading bookings: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _cancelBooking(String bookingId, String stationId, String slotId) async {
    try {
      // Show confirmation dialog
      final bool? confirm = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Cancel Booking'),
            content: const Text(
              'Are you sure you want to cancel this booking? This action cannot be undone.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('No, Keep Booking'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                ),
                child: const Text('Yes, Cancel Booking'),
              ),
            ],
          );
        },
      );

      if (confirm != true) {
        return; // User chose not to cancel
      }

      setState(() => _isLoading = true);

      // Use a transaction to ensure atomic updates
      await _firestore.runTransaction((transaction) async {
        // First, get all required documents
        final bookingDoc = await transaction.get(
          _firestore
              .collection('bookings')
              .doc(bookingId)
        );

        final slotDoc = await transaction.get(
          _firestore
              .collection('charging_slots')
              .doc(stationId)
              .collection('slots')
              .doc(slotId)
        );

        // Verify documents exist
        if (!bookingDoc.exists) {
          throw Exception('Booking not found');
        }

        if (!slotDoc.exists) {
          throw Exception('Slot not found');
        }

        // Get booking data
        final bookingData = bookingDoc.data() as Map<String, dynamic>;
        if (bookingData['status'] != 'booked') {
          throw Exception('Only confirmed bookings can be cancelled');
        }

        // Now perform all updates
        transaction.update(bookingDoc.reference, {
          'status': 'cancelled',
          'cancelledAt': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        });

        transaction.update(slotDoc.reference, {
          'status': 'available',
          'booked_by': null,
          'updated_at': FieldValue.serverTimestamp(),
        });
      });

      // Reload bookings after cancellation
      await _loadBookings();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Booking cancelled successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
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

  String _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'booked':
        return '#4CAF50';
      case 'pending':
        return '#FFC107';
      case 'failed':
        return '#F44336';
      case 'cancelled':
        return '#9E9E9E';
      default:
        return '#9E9E9E';
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'booked':
        return 'Confirmed';
      case 'pending':
        return 'Pending';
      case 'failed':
        return 'Failed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back), // Back arrow icon
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) =>  MapScreen()),
            );
          },
        ),
        title: const Text('My Bookings'),
        backgroundColor: const Color(0xFF0033AA),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _bookings.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.event_busy, size: 64, color: Colors.grey[400]),
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
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _bookings.length,
                  itemBuilder: (context, index) {
                    final booking = _bookings[index];
                    final statusColor = _getStatusColor(booking['status']);
                    final statusText = _getStatusText(booking['status']);
                    final amount = (booking['amount'] as num).toDouble();

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
                                Expanded(
                                  child: Text(
                                    booking['station_name'],
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Color(int.parse(statusColor.replaceAll('#', '0xFF'))),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    statusText,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _buildDetailRow('Vehicle Number', booking['vehicle_number']),
                            _buildDetailRow('Vehicle Model', booking['vehicle_model']),
                            _buildDetailRow('Charging Capacity', '${booking['charging_capacity']} kWh'),
                            _buildDetailRow('Date', booking['date']),
                            _buildDetailRow('Time', booking['time']),
                            const Divider(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Total Amount',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '₹${amount.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0033AA),
                                  ),
                                ),
                              ],
                            ),
                            if (booking['status'] == 'booked') ...[
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () => _cancelBooking(
                                    booking['id'],
                                    booking['station_id'],
                                    '${booking['date']}_${booking['time']}',
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  child: const Text('Cancel Booking'),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
