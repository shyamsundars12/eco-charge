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

class _MyBookingsScreenState extends State<MyBookingsScreen> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = false;
  Map<String, String> _stationNames = {};
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<String> _getStationName(String stationId) async {
    if (_stationNames.containsKey(stationId)) {
      return _stationNames[stationId]!;
    }

    try {
      DocumentSnapshot stationDoc = await _firestore
          .collection('ev_stations')
          .doc(stationId)
          .get();

      if (stationDoc.exists) {
        String stationName = stationDoc['name'] ?? 'Unknown Station';
        _stationNames[stationId] = stationName;
        return stationName;
      }
      return 'Unknown Station';
    } catch (e) {
      print('Error fetching station name: $e');
      return 'Unknown Station';
    }
  }

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
            MaterialPageRoute(builder: (context) => MapScreen()),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withOpacity(0.7),
          tabs: const [
            Tab(text: 'Booked'),
            Tab(text: 'Completed'),
            Tab(text: 'Cancelled'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBookingsList('booked'),
          _buildBookingsList('completed'),
          _buildBookingsList('cancelled'),
        ],
      ),
    );
  }

  Widget _buildBookingsList(String status) {
    // Get current date and time for comparison
    DateTime now = DateTime.now();
    String currentDate = DateFormat('yyyy-MM-dd').format(now);

    Stream<QuerySnapshot> stream;
    if (status == 'booked') {
      // For booked status, show current and future bookings
      stream = _firestore
          .collection('bookings')
          .where('user_id', isEqualTo: _auth.currentUser?.uid)
          .where('status', isEqualTo: status)
          .orderBy('date', descending: false)
          .orderBy('time', descending: false)
          .snapshots();
    } else if (status == 'completed') {
      // For completed status, show both completed and past booked bookings
      stream = _firestore
          .collection('bookings')
          .where('user_id', isEqualTo: _auth.currentUser?.uid)
          .where('status', whereIn: ['completed', 'booked'])
          .orderBy('date', descending: true)
          .orderBy('time', descending: true)
          .snapshots();
    } else {
      // For cancelled status, show all cancelled bookings
      stream = _firestore
          .collection('bookings')
          .where('user_id', isEqualTo: _auth.currentUser?.uid)
          .where('status', isEqualTo: status)
          .orderBy('created_at', descending: true)
          .snapshots();
    }

    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          print('Error in bookings query: ${snapshot.error}');
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
          print('No bookings found for status: $status');
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
                  status == 'booked' 
                      ? 'No upcoming bookings found'
                      : status == 'completed'
                          ? 'No past bookings found'
                          : 'No ${status} bookings found',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }

        // Filter bookings based on date for booked status
        List<QueryDocumentSnapshot> filteredDocs = snapshot.data!.docs;
        if (status == 'booked') {
          filteredDocs = snapshot.data!.docs.where((doc) {
            var booking = doc.data() as Map<String, dynamic>;
            if (booking['date'] == null) return false;
            
            try {
              DateTime bookingDate = DateTime.parse(booking['date']);
              return bookingDate.isAfter(now) || 
                     (bookingDate.year == now.year && 
                      bookingDate.month == now.month && 
                      bookingDate.day == now.day);
            } catch (e) {
              print('Error parsing date: ${booking['date']}');
              return false;
            }
          }).toList();
        }

        if (filteredDocs.isEmpty) {
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
                  status == 'booked' 
                      ? 'No upcoming bookings found'
                      : status == 'completed'
                          ? 'No past bookings found'
                          : 'No ${status} bookings found',
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
          itemCount: filteredDocs.length,
          itemBuilder: (context, index) {
            var booking = filteredDocs[index].data() as Map<String, dynamic>;
            
            // Format the date and time for display
            String formattedDate = 'Not specified';
            String formattedTime = 'Not specified';
            
            if (booking['date'] != null) {
              try {
                DateTime bookingDate = DateTime.parse(booking['date']);
                formattedDate = DateFormat('MMM dd, yyyy').format(bookingDate);
              } catch (e) {
                print('Error formatting date: ${booking['date']}');
                formattedDate = booking['date'].toString();
              }
            }
            
            if (booking['time'] != null) {
              try {
                formattedTime = booking['time'].toString();
              } catch (e) {
                print('Error formatting time: ${booking['time']}');
                formattedTime = booking['time'].toString();
              }
            }

            return FutureBuilder<String>(
              future: _getStationName(booking['station_id']),
              builder: (context, stationNameSnapshot) {
                String stationName = stationNameSnapshot.data ?? 'Loading...';
                
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
                              'Booking #${filteredDocs[index].id.substring(0, 8)}',
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
                                color: _getStatusColor(booking['status']),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                booking['status'].toString().toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildInfoRow('Station', stationName),
                        _buildInfoRow('Date', formattedDate),
                        _buildInfoRow('Time', formattedTime),
                        _buildInfoRow('Charging Point', booking['point_id']?.toString() ?? 'Not specified'),
                        _buildInfoRow('Vehicle Number', booking['vehicle_number']?.toString() ?? 'Not specified'),
                        _buildInfoRow('Vehicle Model', booking['vehicle_model']?.toString() ?? 'Not specified'),
                        _buildInfoRow('Charging Capacity', '${booking['charging_capacity']?.toString() ?? '0'} kWh'),
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
                        if (status == 'booked' && booking['status'] == 'booked') ...[
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => _showCancelConfirmation(filteredDocs[index].id),
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
            );
          },
        );
      },
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
        return const Color(0xFF0033AA); // Dark blue background
      case 'cancelled':
        return Colors.red.shade700; // Dark red background
      case 'completed':
        return Colors.green.shade700; // Dark green background
      default:
        return Colors.grey.shade700; // Dark grey background
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

      // Get booking details
      DocumentSnapshot bookingDoc = await _firestore
          .collection('bookings')
          .doc(bookingId)
          .get();

      if (!bookingDoc.exists) {
        throw Exception('Booking not found');
      }

      Map<String, dynamic> booking = bookingDoc.data() as Map<String, dynamic>;

      // Verify that the booking belongs to the current user
      if (booking['user_id'] != _auth.currentUser?.uid) {
        throw Exception('You can only cancel your own bookings');
      }

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

      // Find and update the charging point status
      bool pointFound = false;
      for (int i = 0; i < chargingPoints.length; i++) {
        if (chargingPoints[i]['id'].toString() == booking['point_id']) {
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
      await _firestore.collection('bookings').doc(bookingId).update({
        'status': 'cancelled',
        'cancelled_at': FieldValue.serverTimestamp(),
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
