import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class ManageSlotsScreen extends StatefulWidget {
  @override
  _ManageSlotsScreenState createState() => _ManageSlotsScreenState();
}

class _ManageSlotsScreenState extends State<ManageSlotsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _ownerEmail;
  String? _selectedStationId;
  List<String> _stationIds = [];
  List<String> _stationNames = [];
  bool _isGeneratingSlots = false;

  @override
  void initState() {
    super.initState();
    _ownerEmail = _auth.currentUser?.email;
    _loadOwnerStations();
    _setupAutomaticSlotManagement();
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
    }
  }

  Future<void> _setupAutomaticSlotManagement() async {
    // Run this every day at midnight
    DateTime now = DateTime.now();
    DateTime nextMidnight = DateTime(now.year, now.month, now.day + 1);
    Duration timeUntilMidnight = nextMidnight.difference(now);

    // Wait until midnight
    await Future.delayed(timeUntilMidnight);

    // Run the cleanup and generation
    await _cleanupAndGenerateSlots();

    // Schedule next run
    _setupAutomaticSlotManagement();
  }

  Future<void> _cleanupAndGenerateSlots() async {
    if (_ownerEmail == null) return;

    try {
      // Get all stations owned by this user
      QuerySnapshot stationsSnapshot = await _firestore
          .collection('ev_stations')
          .where('owner_email', isEqualTo: _ownerEmail)
          .get();

      for (var stationDoc in stationsSnapshot.docs) {
        String stationId = stationDoc.id;
        DateTime now = DateTime.now();
        String today = DateFormat('yyyy-MM-dd').format(now);

        // Delete slots from past dates
        QuerySnapshot pastSlots = await _firestore
            .collection('charging_slots')
            .doc(stationId)
            .collection('slots')
            .where('date', isLessThan: today)
            .get();

        // Delete past slots in batches
        for (var doc in pastSlots.docs) {
          await doc.reference.delete();
        }

        // Generate slots for next 7 days
        await _generateSlotsForStation(stationId);
      }
    } catch (e) {
      print('Error in automatic slot management: $e');
    }
  }

  Future<void> _generateSlotsForStation(String stationId) async {
    try {
      DateTime now = DateTime.now();
      for (int i = 0; i < 7; i++) {
        DateTime date = now.add(Duration(days: i));
        String formattedDate = DateFormat('yyyy-MM-dd').format(date);

        // Check if slots already exist for this date
        QuerySnapshot existingSlots = await _firestore
            .collection('charging_slots')
            .doc(stationId)
            .collection('slots')
            .where('date', isEqualTo: formattedDate)
            .get();

        if (existingSlots.docs.isEmpty) {
          // Generate slots for each day from 8 AM to 8 PM with 30-minute intervals
          for (int hour = 8; hour < 20; hour++) {
            for (int min = 0; min < 60; min += 30) {
              String slotTime = "${hour.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}";
              String slotId = "${formattedDate}_$slotTime";
              
              await _firestore
                  .collection('charging_slots')
                  .doc(stationId)
                  .collection('slots')
                  .doc(slotId)
                  .set({
                'date': formattedDate,
                'time': slotTime,
                'status': 'available',
                'created_at': FieldValue.serverTimestamp(),
                'sort_key': slotId,
              });
            }
          }
        }
      }
    } catch (e) {
      print('Error generating slots for station $stationId: $e');
    }
  }

  Future<void> _generateSlotsFor7Days() async {
    if (_selectedStationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a station first')),
      );
      return;
    }

    setState(() => _isGeneratingSlots = true);

    try {
      await _generateSlotsForStation(_selectedStationId!);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Slots generated successfully for 7 days')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating slots: $e')),
      );
    } finally {
      setState(() => _isGeneratingSlots = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Slots'),
        backgroundColor: Color(0xFF0033AA),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Station Selection Dropdown
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  value: _selectedStationId,
                  decoration: InputDecoration(
                    labelText: 'Select Station',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.ev_station),
                  ),
                  items: List.generate(
                    _stationIds.length,
                    (index) => DropdownMenuItem(
                      value: _stationIds[index],
                      child: Text(_stationNames[index]),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _selectedStationId = value;
                    });
                  },
                ),
                SizedBox(height: 16),
                if (_selectedStationId != null)
                  ElevatedButton.icon(
                    onPressed: _isGeneratingSlots ? null : _generateSlotsFor7Days,
                    icon: _isGeneratingSlots 
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Icon(Icons.calendar_month),
                    label: Text(_isGeneratingSlots ? 'Generating Slots...' : 'Generate Slots for 7 Days'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF0033AA),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
              ],
            ),
          ),

          // Slots List
          Expanded(
            child: _selectedStationId == null
                ? Center(
                    child: Text('Please select a station to manage slots'),
                  )
                : StreamBuilder<QuerySnapshot>(
                    stream: _firestore
                        .collection('charging_slots')
                        .doc(_selectedStationId)
                        .collection('slots')
                        .orderBy('sort_key')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      }

                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator());
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('No slots found for this station'),
                              SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _isGeneratingSlots ? null : _generateSlotsFor7Days,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Color(0xFF0033AA),
                                  foregroundColor: Colors.white,
                                ),
                                child: Text(_isGeneratingSlots ? 'Generating...' : 'Generate Slots for 7 Days'),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: EdgeInsets.all(16),
                        itemCount: snapshot.data!.docs.length,
                        itemBuilder: (context, index) {
                          var doc = snapshot.data!.docs[index];
                          var data = doc.data() as Map<String, dynamic>;
                          
                          return Card(
                            margin: EdgeInsets.only(bottom: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              title: Text(
                                '${data['date'] ?? 'N/A'} - ${data['time'] ?? 'N/A'}',
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
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.edit, color: Color(0xFF0033AA)),
                                    onPressed: () => _showEditSlotDialog(context, doc.id, data),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _showDeleteConfirmation(context, doc.id),
                                  ),
                                ],
                              ),
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

  Future<void> _showEditSlotDialog(BuildContext context, String slotId, Map<String, dynamic> data) async {
    final formKey = GlobalKey<FormState>();
    String status = data['status'] ?? 'available';

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Slot ${data['date']} - ${data['time']}'),
        content: Form(
          key: formKey,
          child: DropdownButtonFormField<String>(
            value: status,
            decoration: InputDecoration(labelText: 'Status'),
            items: [
              DropdownMenuItem(value: 'available', child: Text('Available')),
              DropdownMenuItem(value: 'occupied', child: Text('Occupied')),
              DropdownMenuItem(value: 'maintenance', child: Text('Maintenance')),
            ],
            onChanged: (value) => status = value!,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _firestore
                    .collection('charging_slots')
                    .doc(_selectedStationId)
                    .collection('slots')
                    .doc(slotId)
                    .update({
                  'status': status,
                  'updated_at': FieldValue.serverTimestamp(),
                });
                Navigator.pop(context);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error updating slot: $e')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF0033AA),
              foregroundColor: Colors.white,
            ),
            child: Text('Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _showDeleteConfirmation(BuildContext context, String slotId) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Slot'),
        content: Text('Are you sure you want to delete this slot?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _firestore
                    .collection('charging_slots')
                    .doc(_selectedStationId)
                    .collection('slots')
                    .doc(slotId)
                    .delete();
                Navigator.pop(context);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error deleting slot: $e')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'available':
        return Colors.green;
      case 'occupied':
        return Colors.blue;
      case 'maintenance':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}
