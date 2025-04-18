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

        if (pastSlots.docs.isNotEmpty) {
          print('Deleting ${pastSlots.docs.length} past slots for station $stationId');
          
          // Delete past slots in batches
          for (var doc in pastSlots.docs) {
            await doc.reference.delete();
          }
          
          print('Successfully deleted past slots for station $stationId');
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
      // Get station details
      DocumentSnapshot stationDoc = await _firestore
          .collection('ev_stations')
          .doc(stationId)
          .get();

      if (!stationDoc.exists) {
        throw Exception('Station not found');
      }

      Map<String, dynamic> stationData = stationDoc.data() as Map<String, dynamic>;
      int totalPoints = stationData['total_points'] as int? ?? 5;
      List<String> timeSlots = List<String>.from(stationData['time_slots'] ?? []);

      if (timeSlots.isEmpty) {
        throw Exception('No time slots configured for this station');
      }

      // Generate slots for next 7 days
      for (int i = 0; i < 7; i++) {
        DateTime date = DateTime.now().add(Duration(days: i));
        String formattedDate = DateFormat('yyyy-MM-dd').format(date);

        // Check if slots already exist for this date
        QuerySnapshot existingSlots = await _firestore
            .collection('charging_slots')
            .doc(stationId)
            .collection('slots')
            .where('date', isEqualTo: formattedDate)
            .get();

        if (existingSlots.docs.isEmpty) {
          // Generate slots for each time slot
          for (String time in timeSlots) {
            String slotId = "${formattedDate}_$time";
            
            // Create charging points list
            List<Map<String, dynamic>> chargingPoints = [];
            for (int j = 1; j <= totalPoints; j++) {
              chargingPoints.add({
                'id': j,
                'status': 'available',
                'booked_by': null,
                'pending_by': null,
                'maintenance_note': null,
              });
            }

            // Create the slot document
            await _firestore
                .collection('charging_slots')
                .doc(stationId)
                .collection('slots')
                .doc(slotId)
                .set({
              'date': formattedDate,
              'time': time,
              'station_id': stationId,
              'charging_points': chargingPoints,
              'total_points': totalPoints,
              'available_points': totalPoints,
              'created_at': FieldValue.serverTimestamp(),
              'updated_at': FieldValue.serverTimestamp(),
            });
          }
        }
      }
    } catch (e) {
      print('Error generating slots: $e');
      throw e;
    }
  }

  Future<void> _configureTimeSlots() async {
    if (_selectedStationId == null) return;

    try {
      // Get current time slots configuration
      DocumentSnapshot stationDoc = await _firestore
          .collection('ev_stations')
          .doc(_selectedStationId)
          .get();

      List<String> currentTimeSlots = [];
      if (stationDoc.exists) {
        Map<String, dynamic>? data = stationDoc.data() as Map<String, dynamic>?;
        if (data != null && data.containsKey('time_slots')) {
          currentTimeSlots = List<String>.from(data['time_slots'] ?? []);
        }
      }

      // Show time slots configuration dialog
      final result = await showDialog<List<String>>(
        context: context,
        barrierDismissible: false,
        builder: (context) => WillPopScope(
          onWillPop: () async => false,
          child: TimeSlotsConfigDialog(
            currentTimeSlots: currentTimeSlots,
          ),
        ),
      );

      if (result != null && result.isNotEmpty) {
        // Update or create the time_slots field
        await _firestore
            .collection('ev_stations')
            .doc(_selectedStationId)
            .set({
          'time_slots': result,
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Time slots configured successfully')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error configuring time slots: $e')),
      );
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
      // Check if time slots are configured
      DocumentSnapshot stationDoc = await _firestore
          .collection('ev_stations')
          .doc(_selectedStationId!)
          .get();

      if (!stationDoc.exists) {
        throw Exception('Station not found');
      }

      Map<String, dynamic>? data = stationDoc.data() as Map<String, dynamic>?;
      List<String> timeSlots = [];
      if (data != null && data.containsKey('time_slots')) {
        timeSlots = List<String>.from(data['time_slots'] ?? []);
      }

      if (timeSlots.isEmpty) {
        // Show dialog to configure time slots
        bool? configure = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Configure Time Slots'),
            content: Text('No time slots configured for this station. Would you like to configure them now?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF0033AA),
                  foregroundColor: Colors.white,
                ),
                child: Text('Configure'),
              ),
            ],
          ),
        );

        if (configure == true) {
          await _configureTimeSlots();
          // Try generating slots again after configuration
          await _generateSlotsFor7Days();
        }
        return;
      }

      // First, delete any past slots
      DateTime now = DateTime.now();
      String today = DateFormat('yyyy-MM-dd').format(now);
      
      QuerySnapshot pastSlots = await _firestore
          .collection('charging_slots')
          .doc(_selectedStationId!)
          .collection('slots')
          .where('date', isLessThan: today)
          .get();

      if (pastSlots.docs.isNotEmpty) {
        print('Deleting ${pastSlots.docs.length} past slots');
        
        // Delete past slots in batches
        for (var doc in pastSlots.docs) {
          await doc.reference.delete();
        }
        
        print('Successfully deleted past slots');
      }

      // Then generate new slots
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

  Future<void> _deleteDaySlots(String date) async {
    if (_selectedStationId == null) return;

    try {
      // Show confirmation dialog
      bool? confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Delete Slots'),
          content: Text('Are you sure you want to delete all slots for $date?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text('Delete'),
            ),
          ],
        ),
      );

      if (confirm != true) return;

      // Delete all slots for the selected date
      QuerySnapshot slotsToDelete = await _firestore
          .collection('charging_slots')
          .doc(_selectedStationId)
          .collection('slots')
          .where('date', isEqualTo: date)
          .get();

      for (var doc in slotsToDelete.docs) {
        await doc.reference.delete();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Slots for $date deleted successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting slots: $e')),
      );
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
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
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
                      ),
                      SizedBox(width: 16),
                      ElevatedButton.icon(
                        onPressed: _configureTimeSlots,
                        icon: Icon(Icons.schedule),
                        label: Text('Configure Time Slots'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF0033AA),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                      ),
                    ],
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
                        .orderBy('date')
                        .orderBy('time')
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

                      // Sort the documents by date and time
                      final sortedDocs = snapshot.data!.docs.toList()
                        ..sort((a, b) {
                          final aData = a.data() as Map<String, dynamic>;
                          final bData = b.data() as Map<String, dynamic>;
                          final dateCompare = (aData['date'] ?? '').compareTo(bData['date'] ?? '');
                          if (dateCompare != 0) return dateCompare;
                          return (aData['time'] ?? '').compareTo(bData['time'] ?? '');
                        });

                      // Group slots by date
                      Map<String, List<QueryDocumentSnapshot>> slotsByDate = {};
                      for (var doc in sortedDocs) {
                        var data = doc.data() as Map<String, dynamic>;
                        String date = data['date'] ?? 'Unknown';
                        if (!slotsByDate.containsKey(date)) {
                          slotsByDate[date] = [];
                        }
                        slotsByDate[date]!.add(doc);
                      }

                      return ListView.builder(
                        padding: EdgeInsets.all(16),
                        itemCount: slotsByDate.length,
                        itemBuilder: (context, dateIndex) {
                          String date = slotsByDate.keys.elementAt(dateIndex);
                          List<QueryDocumentSnapshot> dateSlots = slotsByDate[date]!;
                          
                          return Card(
                            margin: EdgeInsets.only(bottom: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 4,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Date Header
                                Container(
                                  padding: EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Color(0xFF0033AA),
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(12),
                                      topRight: Radius.circular(12),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        date,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          Text(
                                            '${dateSlots.length} Time Slots',
                                            style: TextStyle(
                                              color: Colors.white70,
                                              fontSize: 14,
                                            ),
                                          ),
                                          SizedBox(width: 16),
                                          IconButton(
                                            icon: Icon(Icons.delete, color: Colors.white),
                                            onPressed: () => _deleteDaySlots(date),
                                            tooltip: 'Delete all slots for this day',
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsets.all(16),
                                  child: GridView.builder(
                                    shrinkWrap: true,
                                    physics: NeverScrollableScrollPhysics(),
                                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 3,
                                      crossAxisSpacing: 12,
                                      mainAxisSpacing: 12,
                                      childAspectRatio: 1.5,
                                    ),
                                    itemCount: dateSlots.length,
                                    itemBuilder: (context, slotIndex) {
                                      var doc = dateSlots[slotIndex];
                                      var data = doc.data() as Map<String, dynamic>;
                                      
                                      // Safely handle the charging points data
                                      List<Map<String, dynamic>> chargingPoints = [];
                                      if (data['charging_points'] != null) {
                                        if (data['charging_points'] is List) {
                                          chargingPoints = List<Map<String, dynamic>>.from(
                                            (data['charging_points'] as List).map((point) => 
                                              point is Map ? Map<String, dynamic>.from(point) : {}
                                            )
                                          );
                                        }
                                      }
                                      
                                      final availablePoints = chargingPoints.where((point) => point['status'] == 'available').length;
                                      
                                      return GestureDetector(
                                        onTap: () => _showTimeSlotDetails(context, doc.id, data),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(8),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black12,
                                                blurRadius: 4,
                                                offset: Offset(0, 2),
                                              ),
                                            ],
                                            border: Border.all(
                                              color: Color(0xFF0033AA).withOpacity(0.2),
                                            ),
                                          ),
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                data['time'] ?? 'N/A',
                                style: TextStyle(
                                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0033AA),
                                ),
                              ),
                                              SizedBox(height: 8),
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    availablePoints > 0 ? Icons.check_circle : Icons.error,
                                                    color: availablePoints > 0 ? Colors.green : Colors.red,
                                                    size: 16,
                                                  ),
                                                  SizedBox(width: 4),
                                                  Text(
                                                    '$availablePoints/${chargingPoints.length}',
                                style: TextStyle(
                                                      color: availablePoints > 0 ? Colors.green : Colors.red,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
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

  Future<void> _showTimeSlotDetails(BuildContext context, String slotId, Map<String, dynamic> data) async {
    List<Map<String, dynamic>> chargingPoints = [];
    if (data['charging_points'] != null) {
      if (data['charging_points'] is List) {
        chargingPoints = List<Map<String, dynamic>>.from(
          (data['charging_points'] as List).map((point) => 
            point is Map ? Map<String, dynamic>.from(point) : {}
          )
        );
      }
    }

    return showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.85,
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with gradient
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF0033AA), Color(0xFF0066FF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              '${data['date']}',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${chargingPoints.length} Points',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Text(
                        '${data['time']}',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Content
                Flexible(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Status Legend
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.grey[200]!,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildStatusLegend('Available', Colors.green),
                              _buildStatusLegend('Occupied', Colors.blue),
                              _buildStatusLegend('Maintenance', Colors.orange),
                            ],
                          ),
                        ),
                        SizedBox(height: 12),
                        
                        // Charging Points Grid
                        Text(
                          'Charging Points',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0033AA),
                          ),
                        ),
                        SizedBox(height: 8),
                        Container(
                          constraints: BoxConstraints(
                            maxHeight: MediaQuery.of(context).size.height * 0.4,
                          ),
                          child: GridView.builder(
                            shrinkWrap: true,
                            physics: NeverScrollableScrollPhysics(),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                              childAspectRatio: 1.2,
                            ),
                            itemCount: chargingPoints.length,
                            itemBuilder: (context, pointIndex) {
                              final point = chargingPoints[pointIndex];
                              final status = point['status'] as String? ?? 'unknown';
                              final hasMaintenanceNote = point['maintenance_note'] != null;
                              
                              return GestureDetector(
                                onTap: () => _showEditPointDialog(context, slotId, point, data),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(status).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _getStatusColor(status),
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: _getStatusColor(status).withOpacity(0.1),
                                        blurRadius: 8,
                                        offset: Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Stack(
                                    children: [
                                      // Main Content
                                      Padding(
                                        padding: EdgeInsets.all(6),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Container(
                                              width: 28,
                                              height: 28,
                                              decoration: BoxDecoration(
                                                color: _getStatusColor(status),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Center(
                                                child: Text(
                                                  '${point['id'] ?? '?'}',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            SizedBox(height: 4),
                                            Text(
                                              status.toUpperCase(),
                                              style: TextStyle(
                                                color: _getStatusColor(status),
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      
                                      // Maintenance Note Indicator
                                      if (hasMaintenanceNote)
                                        Positioned(
                                          top: 4,
                                          right: 4,
                                          child: Container(
                                            padding: EdgeInsets.all(2),
                                            decoration: BoxDecoration(
                                              color: Colors.orange,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.info,
                                              color: Colors.white,
                                              size: 8,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Footer
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'Close',
                          style: TextStyle(
                            color: Color(0xFF0033AA),
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusLegend(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
        SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey[800],
          ),
        ),
      ],
    );
  }

  Future<void> _showEditPointDialog(BuildContext context, String slotId, Map<String, dynamic> point, Map<String, dynamic> slotData) async {
    String status = point['status'] as String? ?? 'available';
    String? maintenanceNote = point['maintenance_note'] as String?;

    return showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Color(0xFF0033AA),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Text(
                  'Edit Point ${point['id']}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              
              // Content
              Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
                      value: status,
                      decoration: InputDecoration(
                        labelText: 'Status',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Color(0xFF0033AA)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Color(0xFF0033AA)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Color(0xFF0033AA)),
                        ),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        prefixIcon: Icon(Icons.circle, color: _getStatusColor(status)),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'available',
                          child: Row(
                            children: [
                              Icon(Icons.circle, color: Colors.green, size: 16),
                              SizedBox(width: 8),
                              Text('Available'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'occupied',
                          child: Row(
                            children: [
                              Icon(Icons.circle, color: Colors.blue, size: 16),
                              SizedBox(width: 8),
                              Text('Occupied'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'maintenance',
                          child: Row(
                            children: [
                              Icon(Icons.circle, color: Colors.orange, size: 16),
                              SizedBox(width: 8),
                              Text('Maintenance'),
                            ],
                          ),
                        ),
                      ],
                      onChanged: (value) => status = value!,
                    ),
                    SizedBox(height: 20),
                    TextField(
                      decoration: InputDecoration(
                        labelText: 'Maintenance Note (Optional)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Color(0xFF0033AA)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Color(0xFF0033AA)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Color(0xFF0033AA)),
                        ),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                      maxLines: 3,
                      onChanged: (value) => maintenanceNote = value,
                    ),
                  ],
                ),
              ),
              
              // Footer
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
          TextButton(
            onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 16,
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
          ElevatedButton(
            onPressed: () async {
              try {
                          List<Map<String, dynamic>> updatedPoints = List<Map<String, dynamic>>.from(slotData['charging_points']);
                          int pointIndex = updatedPoints.indexWhere((p) => p['id'] == point['id']);
                          if (pointIndex != -1) {
                            updatedPoints[pointIndex] = {
                              ...updatedPoints[pointIndex],
                              'status': status,
                              'maintenance_note': maintenanceNote,
                              'updated_at': DateTime.now().toIso8601String(),
                            };
                          }

                await _firestore
                              .collection('charging_slots')
                    .doc(_selectedStationId)
                    .collection('slots')
                    .doc(slotId)
                    .update({
                            'charging_points': updatedPoints,
                            'available_points': updatedPoints.where((p) => p['status'] == 'available').length,
                            'updated_at': DateTime.now().toIso8601String(),
                });

                Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Point status updated successfully')),
                          );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error updating point: $e')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF0033AA),
              foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
            ),
            child: Text('Update'),
          ),
        ],
      ),
              ),
            ],
          ),
        ),
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

class TimeSlotsConfigDialog extends StatefulWidget {
  final List<String> currentTimeSlots;

  const TimeSlotsConfigDialog({
    Key? key,
    required this.currentTimeSlots,
  }) : super(key: key);

  @override
  _TimeSlotsConfigDialogState createState() => _TimeSlotsConfigDialogState();
}

class _TimeSlotsConfigDialogState extends State<TimeSlotsConfigDialog> {
  List<String> _selectedTimeSlots = [];
  final List<String> _allTimeSlots = List.generate(
    48, // 24 hours * 2 (for 30-minute intervals)
    (index) {
      int hour = index ~/ 2;
      int minute = (index % 2) * 30;
      return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
    },
  );

  @override
  void initState() {
    super.initState();
    _selectedTimeSlots = List.from(widget.currentTimeSlots);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Configure Time Slots',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0033AA),
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Select the time slots for your station (30-minute intervals):',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            Container(
              height: 400,
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 2.0,
                ),
                itemCount: _allTimeSlots.length,
                itemBuilder: (context, index) {
                  final timeSlot = _allTimeSlots[index];
                  final isSelected = _selectedTimeSlots.contains(timeSlot);
                  
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedTimeSlots.remove(timeSlot);
                        } else {
                          _selectedTimeSlots.add(timeSlot);
                        }
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected ? Color(0xFF0033AA) : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? Color(0xFF0033AA) : Colors.grey[300]!,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          timeSlot,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop([]);
                  },
                  child: Text('Cancel'),
                ),
                Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _selectedTimeSlots.clear();
                        });
                      },
                      child: Text('Clear All'),
                    ),
                    SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop(_selectedTimeSlots);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF0033AA),
                        foregroundColor: Colors.white,
                      ),
                      child: Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
