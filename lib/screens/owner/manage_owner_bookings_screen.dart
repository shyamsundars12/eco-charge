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
  String _selectedStatus = 'all'; // 'all', 'active', 'completed', 'cancelled'

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
      });
    } catch (e) {
      print('Error loading stations: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading stations: $e')),
      );
    }
  }

  void _cancelBooking(String bookingId) async {
    try {
      await _firestore.collection('bookings').doc(bookingId).update({
        'status': 'cancelled',
        'updated_at': FieldValue.serverTimestamp(),
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Booking cancelled successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error cancelling booking: $e')),
      );
    }
  }

  Stream<List<QueryDocumentSnapshot>> _getBookingsStream() {
    if (_ownerEmail == null) {
      return Stream.empty();
    }

    // First get all stations owned by this owner
    return _firestore
        .collection('ev_stations')
        .where('owner_email', isEqualTo: _ownerEmail)
        .snapshots()
        .asyncMap((stationsSnapshot) async {
          if (stationsSnapshot.docs.isEmpty) {
            return [];
          }

          // Get all station IDs owned by this owner
          List<String> stationIds = stationsSnapshot.docs.map((doc) => doc.id).toList();
          
          // If a specific station is selected, filter by that station
          if (_selectedStationId != null) {
            stationIds = [_selectedStationId!];
          }

          // Get bookings for all stations
          List<QuerySnapshot> bookingSnapshots = await Future.wait(
            stationIds.map((stationId) => _firestore
                .collection('bookings')
                .where('stationId', isEqualTo: stationId)
                .where('status', isEqualTo: _selectedStatus == 'all' ? null : _selectedStatus)
                .get()),
          );

          // Combine all bookings into a single list
          List<QueryDocumentSnapshot> allBookings = [];
          for (var snapshot in bookingSnapshots) {
            allBookings.addAll(snapshot.docs);
          }

          // Sort bookings by date
          allBookings.sort((a, b) {
            var aData = a.data() as Map<String, dynamic>;
            var bData = b.data() as Map<String, dynamic>;
            var aDate = aData['timestamp'] as Timestamp?;
            var bDate = bData['timestamp'] as Timestamp?;
            if (aDate == null) return 1;
            if (bDate == null) return -1;
            return bDate.compareTo(aDate);
          });

          return allBookings;
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
        title: Text('Manage Station Bookings'),
        backgroundColor: Color(0xFF0033AA),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Station Selection and Status Filter
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                // Station Selection Dropdown
                DropdownButtonFormField<String>(
                  value: _selectedStationId,
                  decoration: InputDecoration(
                    labelText: 'Select Station',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.ev_station),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: null,
                      child: Text('All Stations'),
                    ),
                    ...List.generate(
                      _stationIds.length,
                      (index) => DropdownMenuItem(
                        value: _stationIds[index],
                        child: Text(_stationNames[index]),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedStationId = value;
                    });
                  },
                ),
                SizedBox(height: 16),
                // Status Filter
                Row(
                  children: [
                    Text('Filter by Status: ', 
                      style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(width: 10),
                    DropdownButton<String>(
                      value: _selectedStatus,
                      items: [
                        DropdownMenuItem(value: 'all', child: Text('All')),
                        DropdownMenuItem(value: 'confirmed', child: Text('Confirmed')),
                        DropdownMenuItem(value: 'completed', child: Text('Completed')),
                        DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedStatus = value!;
                        });
                      },
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
                        Icon(Icons.error_outline, color: Colors.red, size: 48),
                        SizedBox(height: 16),
                        Text('Error: ${snapshot.error}'),
                        SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => setState(() {}),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF0033AA),
                            foregroundColor: Colors.white,
                          ),
                          child: Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.event_busy, color: Colors.grey, size: 48),
                        SizedBox(height: 16),
                        Text('No bookings found'),
                        if (_selectedStatus != 'all')
                          Text('Try changing the status filter'),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    var doc = snapshot.data![index];
                    var data = doc.data() as Map<String, dynamic>;
                    
                    return Card(
                      margin: EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ExpansionTile(
                        title: Text(
                          'Booking #${doc.id.substring(0, 8)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0033AA),
                          ),
                        ),
                        subtitle: Text(
                          'Status: ${data['status'] ?? 'Unknown'}',
                          style: TextStyle(
                            color: _getStatusColor(data['status']),
                          ),
                        ),
                        children: [
                          Padding(
                            padding: EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                FutureBuilder<String>(
                                  future: _getStationName(data['stationId']),
                                  builder: (context, stationSnapshot) {
                                    return _buildInfoRow(
                                      'Station',
                                      stationSnapshot.data ?? 'Loading...'
                                    );
                                  },
                                ),
                                FutureBuilder<String>(
                                  future: _getUserName(data['userId']),
                                  builder: (context, userSnapshot) {
                                    return _buildInfoRow(
                                      'User Name',
                                      userSnapshot.data ?? 'Loading...'
                                    );
                                  },
                                ),
                                _buildInfoRow('Date', data['date'] ?? 'N/A'),
                                _buildInfoRow('Slot Time', data['slotTime'] ?? 'N/A'),
                                _buildInfoRow('Amount', '₹${data['amount']?.toString() ?? '0.00'}'),
                                _buildInfoRow('Vehicle Model', data['vehicleModel'] ?? 'N/A'),
                                _buildInfoRow('Vehicle Number', data['vehicleNumber'] ?? 'N/A'),
                                _buildInfoRow('Charging Capacity', '${data['chargingCapacity'] ?? 'N/A'} kW'),
                                _buildInfoRow('Payment Status', data['paymentStatus'] ?? 'N/A'),
                                _buildInfoRow('Payment ID', data['paymentId'] ?? 'N/A'),
                                _buildInfoRow('Booking Time', _formatDate(data['timestamp'])),
                                _buildInfoRow('Payment Time', _formatDate(data['paymentTimestamp'])),
                                if (data['status'] == 'confirmed')
                                  Padding(
                                    padding: EdgeInsets.only(top: 16),
                                    child: ElevatedButton(
                                      onPressed: () => _showCancelConfirmation(context, doc.id),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        foregroundColor: Colors.white,
                                      ),
                                      child: Text('Cancel Booking'),
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

  Widget _buildInfoRow(String label, String value) {
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
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'confirmed':
        return Colors.green;
      case 'completed':
        return Colors.blue;
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

  Future<void> _showCancelConfirmation(BuildContext context, String bookingId) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cancel Booking'),
        content: Text('Are you sure you want to cancel this booking?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('No'),
          ),
          ElevatedButton(
            onPressed: () {
              _cancelBooking(bookingId);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('Yes, Cancel'),
          ),
        ],
      ),
    );
  }
} 