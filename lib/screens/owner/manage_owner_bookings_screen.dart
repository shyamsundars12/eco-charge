import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class ManageOwnerBookingsScreen extends StatefulWidget {
  @override
  _ManageOwnerBookingsScreenState createState() => _ManageOwnerBookingsScreenState();
}

class _ManageOwnerBookingsScreenState extends State<ManageOwnerBookingsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _ownerEmail;
  String? _selectedStationId;
  List<String> _stationIds = [];
  List<String> _stationNames = [];
  String _selectedStatus = 'all'; // 'all', 'booked', 'cancelled'

  @override
  void initState() {
    super.initState();
    _ownerEmail = _auth.currentUser?.email;
    _loadOwnerStations();
  }

  Future<void> _loadOwnerStations() async {
    if (_ownerEmail == null) return;

    try {
      QuerySnapshot stationsSnapshot = await _firestore
          .collection('ev_stations')
          .where('owner_email', isEqualTo: _ownerEmail)
          .get();

      setState(() {
        _stationIds = stationsSnapshot.docs.map((doc) => doc.id).toList();
        _stationNames = stationsSnapshot.docs.map((doc) => doc['name'] as String).toList();
        if (_stationIds.isNotEmpty) {
          _selectedStationId = _stationIds.first; // Select first station by default
        }
      });
    } catch (e) {
      print('Error loading stations: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading stations: $e')),
      );
    }
  }

  Stream<List<QueryDocumentSnapshot>> _getBookingsStream() {
    if (_ownerEmail == null || _selectedStationId == null) {
      return Stream.empty();
    }

    // Query bookings for the selected station
    Query query = _firestore
        .collection('bookings')
        .where('station_id', isEqualTo: _selectedStationId)
        .orderBy('created_at', descending: true);

    return query.snapshots().map((snapshot) {
      List<QueryDocumentSnapshot> filteredBookings = snapshot.docs;

      // Filter by status if not 'all'
      if (_selectedStatus != 'all') {
        filteredBookings = filteredBookings.where((doc) {
          var data = doc.data() as Map<String, dynamic>;
          return data['status']?.toString().toLowerCase() == _selectedStatus.toLowerCase();
        }).toList();
      }

      return filteredBookings;
    });
  }

  Future<String> _getStationName(String stationId) async {
    try {
      DocumentSnapshot stationDoc = await _firestore.collection('ev_stations').doc(stationId).get();
      Map<String, dynamic>? data = stationDoc.data() as Map<String, dynamic>?;
      return data?['name'] as String? ?? 'Unknown Station';
    } catch (e) {
      print('Error getting station name: $e');
      return 'Unknown Station';
    }
  }

  Future<String> _getUserName(String userId) async {
    try {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(userId).get();
      Map<String, dynamic>? data = userDoc.data() as Map<String, dynamic>?;
      return data?['name'] as String? ?? 'Unknown User';
    } catch (e) {
      print('Error getting user name: $e');
      return 'Unknown User';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Bookings'),
        backgroundColor: const Color(0xFF0033AA),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Station Selection Dropdown
                DropdownButtonFormField<String>(
                  value: _selectedStationId,
                  decoration: const InputDecoration(
                    labelText: 'Select Station',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.ev_station),
                  ),
                  items: _stationIds.asMap().entries.map((entry) {
                    return DropdownMenuItem(
                      value: entry.value,
                      child: Text(_stationNames[entry.key]),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedStationId = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                // Status Filter Chips
                Wrap(
                  spacing: 8,
                  children: [
                    FilterChip(
                      label: const Text('All'),
                      selected: _selectedStatus == 'all',
                      onSelected: (selected) {
                        setState(() => _selectedStatus = 'all');
                      },
                      backgroundColor: Colors.grey[200],
                      selectedColor: const Color(0xFF0033AA).withOpacity(0.2),
                      labelStyle: TextStyle(
                        color: _selectedStatus == 'all' 
                            ? const Color(0xFF0033AA) 
                            : Colors.black87,
                        fontWeight: _selectedStatus == 'all' 
                            ? FontWeight.bold 
                            : FontWeight.normal,
                      ),
                    ),
                    FilterChip(
                      label: const Text('Booked'),
                      selected: _selectedStatus == 'booked',
                      onSelected: (selected) {
                        setState(() => _selectedStatus = 'booked');
                      },
                      backgroundColor: Colors.grey[200],
                      selectedColor: Colors.green.withOpacity(0.2),
                      labelStyle: TextStyle(
                        color: _selectedStatus == 'booked' 
                            ? Colors.green[800] 
                            : Colors.black87,
                        fontWeight: _selectedStatus == 'booked' 
                            ? FontWeight.bold 
                            : FontWeight.normal,
                      ),
                    ),
                    FilterChip(
                      label: const Text('Cancelled'),
                      selected: _selectedStatus == 'cancelled',
                      onSelected: (selected) {
                        setState(() => _selectedStatus = 'cancelled');
                      },
                      backgroundColor: Colors.grey[200],
                      selectedColor: Colors.red.withOpacity(0.2),
                      labelStyle: TextStyle(
                        color: _selectedStatus == 'cancelled' 
                            ? Colors.red 
                            : Colors.black87,
                        fontWeight: _selectedStatus == 'cancelled' 
                            ? FontWeight.bold 
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Bookings List
          Expanded(
            child: StreamBuilder<List<QueryDocumentSnapshot>>(
              stream: _getBookingsStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 48),
                        const SizedBox(height: 16),
                        Text('Error: ${snapshot.error}'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => setState(() {}),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0033AA),
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.event_busy, color: Colors.grey, size: 48),
                        SizedBox(height: 16),
                        Text('No bookings found'),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    var doc = snapshot.data![index];
                    var data = doc.data() as Map<String, dynamic>;
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ExpansionTile(
                        title: Text(
                          'Booking #${doc.id.substring(0, 8)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0033AA),
                          ),
                        ),
                        subtitle: Text(
                          'Status: ${data['status']?.toString() ?? 'Unknown'}',
                          style: TextStyle(
                            color: _getStatusColor(data['status']?.toString()),
                          ),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                FutureBuilder<String>(
                                  future: _getStationName(data['station_id']?.toString() ?? ''),
                                  builder: (context, stationSnapshot) {
                                    return _buildInfoRow(
                                      'Station',
                                      stationSnapshot.data ?? 'Loading...'
                                    );
                                  },
                                ),
                                FutureBuilder<String>(
                                  future: _getUserName(data['user_id']?.toString() ?? ''),
                                  builder: (context, userSnapshot) {
                                    return _buildInfoRow(
                                      'User Name',
                                      userSnapshot.data ?? 'Loading...'
                                    );
                                  },
                                ),
                                _buildInfoRow('Date', data['date']?.toString() ?? 'N/A'),
                                _buildInfoRow('Time', data['time']?.toString() ?? 'N/A'),
                                _buildInfoRow('Vehicle Number', data['vehicle_number']?.toString() ?? 'N/A'),
                                _buildInfoRow('Vehicle Model', data['vehicle_model']?.toString() ?? 'N/A'),
                                _buildInfoRow('Charging Point', data['point_id']?.toString() ?? 'N/A'),
                                _buildInfoRow('Charging Capacity', '${data['charging_capacity']?.toString() ?? 'N/A'} kWh'),
                                const Divider(height: 24),
                                _buildInfoRow(
                                  'Total Amount', 
                                  '₹${(data['total_amount'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                                  isAmount: true
                                ),
                                _buildInfoRow(
                                  'Advance Paid', 
                                  '₹${(data['advance_paid'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                                  isAmount: true
                                ),
                                _buildInfoRow(
                                  'Remaining Amount', 
                                  '₹${(data['remaining_amount'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                                  isAmount: true
                                ),
                                const SizedBox(height: 16),
                                if (data['status']?.toString().toLowerCase() == 'booked')
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: () => _showConfirmationDialog(context, doc.id, 'cancel'),
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
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isAmount = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: isAmount ? Colors.black87 : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'booked':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    if (timestamp is Timestamp) {
      return DateFormat('dd MMM yyyy, hh:mm a').format(timestamp.toDate());
    }
    return 'N/A';
  }

  Future<void> _showConfirmationDialog(BuildContext context, String bookingId, String action) async {
    String title = action == 'confirm' ? 'Confirm Booking' : 'Cancel Booking';
    String message = action == 'confirm' 
        ? 'Are you sure you want to confirm this booking?'
        : 'Are you sure you want to cancel this booking?';
    Color buttonColor = action == 'confirm' ? Colors.green : Colors.red;

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (action == 'confirm') {
                _confirmBooking(bookingId);
              } else {
                _cancelBooking(bookingId);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonColor,
              foregroundColor: Colors.white,
            ),
            child: Text('Yes, ${action == 'confirm' ? 'Confirm' : 'Cancel'}'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmBooking(String bookingId) async {
    try {
      await _firestore.collection('bookings').doc(bookingId).update({
        'status': 'confirmed',
        'updated_at': FieldValue.serverTimestamp(),
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Booking confirmed successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error confirming booking: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _cancelBooking(String bookingId) async {
    try {
      // Get booking details
      DocumentSnapshot bookingDoc = await _firestore
          .collection('bookings')
          .doc(bookingId)
          .get();

      if (!bookingDoc.exists) {
        throw Exception('Booking not found');
      }

      Map<String, dynamic> booking = bookingDoc.data() as Map<String, dynamic>;

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
        'updated_at': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Booking cancelled successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error cancelling booking: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
} 