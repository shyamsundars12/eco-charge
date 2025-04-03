import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class OwnerWiseReportsScreen extends StatefulWidget {
  @override
  _OwnerWiseReportsScreenState createState() => _OwnerWiseReportsScreenState();
}

class _OwnerWiseReportsScreenState extends State<OwnerWiseReportsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, dynamic> _ownerStats = {};
  bool _isLoading = true;
  String _selectedTimeRange = 'all'; // 'all', 'today', 'week', 'month'
  
  @override
  void initState() {
    super.initState();
    _fetchOwnerStats();
  }

  Future<void> _fetchOwnerStats() async {
    setState(() => _isLoading = true);
    
    try {
      // Get all owners
      QuerySnapshot ownersSnapshot = await _firestore
          .collection('ev_stations')
          .get();

      Map<String, dynamic> ownerStats = {};

      // For each owner, get their stations and bookings
      for (var station in ownersSnapshot.docs) {
        String ownerEmail = station['owner_email'] ?? 'Unassigned';
        
        // Skip if owner email is empty
        if (ownerEmail.isEmpty) continue;

        // Initialize owner stats if not exists
        if (!ownerStats.containsKey(ownerEmail)) {
          ownerStats[ownerEmail] = {
            'total_bookings': 0,
            'total_revenue': 0.0,
            'active_bookings': 0,
            'cancelled_bookings': 0,
            'stations': [],
          };
        }

        // Add station to owner's stations list
        ownerStats[ownerEmail]['stations'].add({
          'id': station.id,
          'name': station['name'],
        });

        // Get bookings for this station
        QuerySnapshot bookingsSnapshot;
        
        switch (_selectedTimeRange) {
          case 'today':
            DateTime today = DateTime.now();
            DateTime startOfDay = DateTime(today.year, today.month, today.day);
            bookingsSnapshot = await _firestore
                .collection('bookings')
                .where('station_id', isEqualTo: station.id)
                .where('created_at', isGreaterThanOrEqualTo: startOfDay)
                .get();
            break;
            
          case 'week':
            DateTime now = DateTime.now();
            DateTime weekAgo = now.subtract(Duration(days: 7));
            bookingsSnapshot = await _firestore
                .collection('bookings')
                .where('station_id', isEqualTo: station.id)
                .where('created_at', isGreaterThanOrEqualTo: weekAgo)
                .get();
            break;
            
          case 'month':
            DateTime now = DateTime.now();
            DateTime monthAgo = DateTime(now.year, now.month - 1, now.day);
            bookingsSnapshot = await _firestore
                .collection('bookings')
                .where('station_id', isEqualTo: station.id)
                .where('created_at', isGreaterThanOrEqualTo: monthAgo)
                .get();
            break;
            
          default: // all time
            bookingsSnapshot = await _firestore
                .collection('bookings')
                .where('station_id', isEqualTo: station.id)
                .get();
        }

        // Update owner stats with booking data
        for (var booking in bookingsSnapshot.docs) {
          ownerStats[ownerEmail]['total_bookings']++;
          ownerStats[ownerEmail]['total_revenue'] += 
              (booking['amount_paid'] ?? 0.0).toDouble();

          String status = booking['status'] ?? '';
          if (status == 'Active' || status == 'Confirmed') {
            ownerStats[ownerEmail]['active_bookings']++;
          } else if (status == 'Cancelled') {
            ownerStats[ownerEmail]['cancelled_bookings']++;
          }
        }
      }

      setState(() {
        _ownerStats = ownerStats;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching owner stats: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Owner-wise Reports'),
        backgroundColor: Color(0xFF0033AA),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Time range selector
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Text('Time Range: ', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(width: 10),
                DropdownButton<String>(
                  value: _selectedTimeRange,
                  items: [
                    DropdownMenuItem(value: 'all', child: Text('All Time')),
                    DropdownMenuItem(value: 'today', child: Text('Today')),
                    DropdownMenuItem(value: 'week', child: Text('Last 7 Days')),
                    DropdownMenuItem(value: 'month', child: Text('Last 30 Days')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedTimeRange = value!;
                    });
                    _fetchOwnerStats();
                  },
                ),
              ],
            ),
          ),
          
          // Stats cards
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _ownerStats.isEmpty
                    ? Center(child: Text('No owner data available'))
                    : ListView.builder(
                        padding: EdgeInsets.all(16),
                        itemCount: _ownerStats.length,
                        itemBuilder: (context, index) {
                          String ownerEmail = _ownerStats.keys.elementAt(index);
                          var stats = _ownerStats[ownerEmail];
                          
                          return Card(
                            elevation: 4,
                            margin: EdgeInsets.only(bottom: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ExpansionTile(
                              title: Text(
                                ownerEmail,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0033AA),
                                ),
                              ),
                              children: [
                                Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildStatRow(
                                        'Total Bookings',
                                        stats['total_bookings'].toString(),
                                        Icons.book,
                                      ),
                                      _buildStatRow(
                                        'Active Bookings',
                                        stats['active_bookings'].toString(),
                                        Icons.check_circle,
                                      ),
                                      _buildStatRow(
                                        'Cancelled Bookings',
                                        stats['cancelled_bookings'].toString(),
                                        Icons.cancel,
                                      ),
                                      _buildStatRow(
                                        'Total Revenue',
                                        '₹${stats['total_revenue'].toStringAsFixed(2)}',
                                        Icons.currency_rupee,
                                      ),
                                      SizedBox(height: 10),
                                      Text(
                                        'Stations:',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      ...stats['stations'].map<Widget>((station) {
                                        return Padding(
                                          padding: EdgeInsets.only(left: 16, top: 4),
                                          child: Text(
                                            '• ${station['name']}',
                                            style: TextStyle(fontSize: 14),
                                          ),
                                        );
                                      }).toList(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Color(0xFF0033AA)),
          SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(fontSize: 14),
          ),
          Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0033AA),
            ),
          ),
        ],
      ),
    );
  }
} 