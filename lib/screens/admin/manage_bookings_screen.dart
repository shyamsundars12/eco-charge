import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ManageBookingsScreen extends StatefulWidget {
  @override
  _ManageBookingsScreenState createState() => _ManageBookingsScreenState();
}

class _ManageBookingsScreenState extends State<ManageBookingsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _selectedStationId = 'all'; // Default to 'all'
  List<String> _stationIds = [];
  List<String> _stationNames = [];
  String _selectedStatus = 'all'; // 'all', 'booked', 'cancelled'

  @override
  void initState() {
    super.initState();
    _loadStations();
  }

  Future<void> _loadStations() async {
    try {
      QuerySnapshot stationsSnapshot = await _firestore.collection('ev_stations').get();
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

  Stream<List<QueryDocumentSnapshot>> _getBookingsStream() {
    Query query = _firestore.collection('bookings');

    // Add station filter if not 'all'
    if (_selectedStationId != 'all') {
      query = query.where('station_id', isEqualTo: _selectedStationId);
    }

    // Always order by created_at
    query = query.orderBy('created_at', descending: true);

    return query.snapshots().map((snapshot) {
      List<QueryDocumentSnapshot> filteredBookings = snapshot.docs;

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

  Future<void> _cancelBooking(String bookingId) async {
    try {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage All Bookings'),
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
                  items: [
                    const DropdownMenuItem(
                      value: 'all',
                      child: Text('All Stations'),
                    ),
                    ..._stationIds.asMap().entries.map((entry) {
                      return DropdownMenuItem(
                        value: entry.value,
                        child: Text(_stationNames[entry.key]),
                      );
                    }).toList(),
                  ],
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
                                _buildInfoRow('Payment Status', data['payment_status']?.toString() ?? 'N/A'),
                                _buildInfoRow('Payment ID', data['payment_id']?.toString() ?? 'N/A'),
                                _buildInfoRow('Booking Time', _formatDate(data['created_at'])),
                                _buildInfoRow('Payment Time', _formatDate(data['payment_timestamp'])),
                                const SizedBox(height: 16),
                                if (data['status']?.toString().toLowerCase() == 'booked')
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: () => _showConfirmationDialog(context, doc.id),
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: isAmount ? Colors.green[800] : Colors.black87,
                fontWeight: isAmount ? FontWeight.bold : FontWeight.normal,
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

  Future<void> _showConfirmationDialog(BuildContext context, String bookingId) async {
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
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _cancelBooking(bookingId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
  }
}
