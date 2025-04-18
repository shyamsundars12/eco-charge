import 'package:ecocharge/screens/user/vehicle_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SlotBookingScreen extends StatefulWidget {
  final String stationId;
  final String stationName;
  final String selectedDate;

  const SlotBookingScreen({
    Key? key,
    required this.stationId,
    required this.stationName,
    required this.selectedDate,
  }) : super(key: key);

  @override
  _SlotBookingScreenState createState() => _SlotBookingScreenState();
}

class _SlotBookingScreenState extends State<SlotBookingScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  DateTime selectedDate = DateTime.now();
  String selectedSlotTime = "";
  String? selectedPointId;
  bool _isLoading = false;
  String? _errorMessage;
  late String _stationName;
  String? _userId;
  String? selectedSlotId;

  @override
  void initState() {
    super.initState();
    _stationName = widget.stationName;
    _userId = _auth.currentUser?.uid;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("Book Slot - $_stationName", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Color(0xFF0033AA),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          SizedBox(height: 20),
          buildDateSelector(),
          SizedBox(height: 50),
          Expanded(child: buildSlotGrid()),
          if (selectedSlotTime.isNotEmpty) SizedBox(height: 20),
          if (selectedSlotTime.isNotEmpty) buildContinueButton(),
        ],
      ),
    );
  }

  /// ✅ Date Selector
  Widget buildDateSelector() {
    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 7,
        itemBuilder: (context, index) {
          DateTime date = DateTime.now().add(Duration(days: index));
          bool isSelected = selectedDate.day == date.day;

          return GestureDetector(
            onTap: () => setState(() => selectedDate = date),
            child: AnimatedContainer(
              duration: Duration(milliseconds: 300),
              margin: EdgeInsets.symmetric(horizontal: 6),
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : Color(0xFF0033AA),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  if (isSelected)
                    BoxShadow(color: Color(0xFF0033AA).withOpacity(0.3), blurRadius: 8, offset: Offset(0, 4))
                ],
                border: Border.all(color: isSelected ? Color(0xFF0033AA) : Colors.white),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(DateFormat('E').format(date), style: TextStyle(color: isSelected ? Color(0xFF0033AA) : Colors.white)),
                  Text("${date.day}", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isSelected ? Color(0xFF0033AA) : Colors.white)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// ✅ Fetch Slots from Firestore
  Widget buildSlotGrid() {
    String formattedDate = DateFormat('yyyy-MM-dd').format(selectedDate);
    DateTime now = DateTime.now();
    DateTime thresholdTime = now.add(Duration(minutes: 30));
    String currentHourMinute = DateFormat('HH:mm').format(thresholdTime);

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('charging_slots')
          .doc(widget.stationId)
          .collection('slots')
          .where('date', isEqualTo: formattedDate)
          .orderBy('time')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          String errorMessage = snapshot.error.toString();
          if (errorMessage.contains('FAILED_PRECONDITION')) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.schedule, color: Colors.orange, size: 48),
                    SizedBox(height: 16),
                    Text(
                      "Setting up the system...",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange),
                    ),
                    SizedBox(height: 8),
                    Text(
                      "Please wait a few minutes and try again.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                    SizedBox(height: 16),
                    Text(
                      "If the issue persists, please contact support.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                    SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF0033AA),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: Text("Go Back"),
                    ),
                  ],
                ),
              ),
            );
          }
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 50),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_busy, color: Color(0xFF0033AA), size: 48),
                  SizedBox(height: 16),
                  Text(
                "No available slots for this date.",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0033AA)),
                  ),
                ],
              ),
            ),
          );
        }

        var slots = snapshot.data!.docs.where((doc) {
          String slotTime = (doc.data() as Map<String, dynamic>)['time'];
          return selectedDate.day != now.day || slotTime.compareTo(currentHourMinute) >= 0;
        }).toList();

        if (slots.isEmpty) {
          return Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 50),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_busy, color: Color(0xFF0033AA), size: 48),
                  SizedBox(height: 16),
                  Text(
                    "No available slots from the current time.",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0033AA)),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: slots.length,
          itemBuilder: (context, index) {
            var doc = slots[index];
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
            String slotTime = data['time'];
            bool isSelected = selectedSlotTime == slotTime;

            // Get charging points
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

            return Card(
              margin: EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Time Slot Header
                  Container(
                    padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSelected ? Color(0xFF0033AA) : Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                  slotTime,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Color(0xFF0033AA),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white.withOpacity(0.2) : Color(0xFF0033AA).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                availablePoints > 0 ? Icons.check_circle : Icons.error,
                                color: isSelected ? Colors.white : (availablePoints > 0 ? Colors.green : Colors.red),
                                size: 16,
                              ),
                              SizedBox(width: 4),
                              Text(
                                '$availablePoints/${chargingPoints.length}',
                                style: TextStyle(
                                  color: isSelected ? Colors.white : (availablePoints > 0 ? Colors.green : Colors.red),
                    fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Charging Points Grid
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Charging Points',
                          style: TextStyle(
                    fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0033AA),
                          ),
                        ),
                        SizedBox(height: 12),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 5,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            childAspectRatio: 1,
                          ),
                          itemCount: chargingPoints.length,
                          itemBuilder: (context, pointIndex) {
                            final point = chargingPoints[pointIndex];
                            final status = point['status'] as String? ?? 'unknown';
                            final pointId = point['id'].toString();
                            final hasMaintenanceNote = point['maintenance_note'] != null;
                            final isPointSelected = selectedPointId == pointId && selectedSlotTime == slotTime;
                            final isAvailable = status == 'available';
                            
                            return GestureDetector(
                              onTap: isAvailable ? () {
                                setState(() {
                                  selectedSlotTime = slotTime;
                                  selectedPointId = pointId;
                                });
                              } : null,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: _getStatusColor(status).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isPointSelected ? Color(0xFF0033AA) : _getStatusColor(status),
                                    width: isPointSelected ? 3 : 2,
                                  ),
                                ),
                                child: Stack(
                                  children: [
                                    // Main Content
                                    Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            width: 24,
                                            height: 24,
                                            decoration: BoxDecoration(
                                              color: _getStatusColor(status),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Center(
                                              child: Text(
                                                pointId,
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
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
                                              fontSize: 8,
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
                      ],
                    ),
                  ),
                  
                  // Book Button
                  if (selectedPointId != null && selectedSlotTime == slotTime)
                    Padding(
                      padding: EdgeInsets.all(16),
                      child: ElevatedButton(
                        onPressed: () => _createBooking(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF0033AA),
                          foregroundColor: Colors.white,
                          minimumSize: Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'Book Point $selectedPointId',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
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

  /// ✅ "Book Slot" Button
  Widget buildContinueButton() {
    return Padding(
      padding: EdgeInsets.all(15),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Color(0xFF0033AA),
          foregroundColor: Colors.white,
          minimumSize: Size(double.infinity, 55),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          shadowColor: Colors.white.withOpacity(0.4),
          elevation: 6,
        ),
        onPressed: _createBooking,
        child: Text("Book Slot", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }

  /// ✅ Book Slot and Navigate to Vehicle Details Screen
  Future<void> _createBooking() async {
    if (_userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please login to book a slot'), backgroundColor: Colors.red),
      );
      return;
    }

    try {
      if (selectedSlotTime.isEmpty || selectedPointId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please select a charging point first'), backgroundColor: Colors.red),
        );
        return;
      }

      String formattedDate = DateFormat('yyyy-MM-dd').format(selectedDate);
      String slotId = "${formattedDate}_$selectedSlotTime";

      // Get the current slot document
      DocumentSnapshot slotDoc = await _firestore
          .collection('charging_slots')
          .doc(widget.stationId)
          .collection('slots')
          .doc(slotId)
          .get();

      if (!slotDoc.exists) {
        throw Exception('Slot not found');
      }

      Map<String, dynamic> slotData = slotDoc.data() as Map<String, dynamic>;
      List<dynamic> chargingPoints = List.from(slotData['charging_points'] ?? []);

      // Find and update the selected charging point
      bool pointFound = false;
      for (int i = 0; i < chargingPoints.length; i++) {
        if (chargingPoints[i]['id'].toString() == selectedPointId) {
          if (chargingPoints[i]['status'] != 'available') {
            throw Exception('This charging point is not available');
          }
          chargingPoints[i]['status'] = 'pending';
          chargingPoints[i]['pending_by'] = _userId;
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
          .doc(widget.stationId)
          .collection('slots')
          .doc(slotId)
          .update({
        'charging_points': chargingPoints,
        'updated_at': FieldValue.serverTimestamp(),
      });

      // Navigate to vehicle details screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VehicleDetailsScreen(
            stationId: widget.stationId,
            slotTime: selectedSlotTime,
            selectedDate: formattedDate,
            slotId: slotId,
            pointId: selectedPointId!,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error booking slot: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showSlotDetails(BuildContext context, String slotTime) async {
    if (_userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please login to book a slot'), backgroundColor: Colors.red),
      );
      return;
    }

    try {
      String formattedDate = DateFormat('yyyy-MM-dd').format(selectedDate);
      String slotId = "${formattedDate}_$slotTime";

      // Get the slot document to show details
      DocumentSnapshot slotDoc = await _firestore
          .collection('charging_slots')
          .doc(widget.stationId)
          .collection('slots')
          .doc(slotId)
          .get();

      if (!slotDoc.exists) {
        throw Exception('Slot not found');
      }

      Map<String, dynamic> slotData = slotDoc.data() as Map<String, dynamic>;
      List<dynamic> chargingPoints = List.from(slotData['charging_points'] ?? []);

      // Show the slot details in a dialog
      showDialog(
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
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Slot Details',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0033AA),
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Date: $formattedDate',
                    style: TextStyle(fontSize: 16),
                  ),
                  Text(
                    'Time: $slotTime',
                    style: TextStyle(fontSize: 16),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Charging Points',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 1,
                    ),
                    itemCount: chargingPoints.length,
                    itemBuilder: (context, index) {
                      final point = chargingPoints[index];
                      final status = point['status'] as String? ?? 'unknown';
                      final pointId = (point['id']?.toString() ?? '') as String;
                      final hasMaintenanceNote = point['maintenance_note'] != null;
                      
                      return Container(
                        decoration: BoxDecoration(
                          color: _getStatusColor(status).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _getStatusColor(status),
                            width: 2,
                          ),
                        ),
                        child: Stack(
                          children: [
                            Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(status),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        pointId,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
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
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
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
                      );
                    },
                  ),
                  SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('Close'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error showing slot details: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Color _getPointColor(Map<String, dynamic>? point) {
    if (point == null) return Colors.grey;
    
    final status = point['status'] as String? ?? 'unknown';
    switch (status.toLowerCase()) {
      case 'available':
        return Colors.green;
      case 'occupied':
        return Colors.blue;
      case 'maintenance':
        return Colors.orange;
      case 'booked':
        return Colors.red;
      case 'pending':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Widget _buildTimeSlotCard(Map<String, dynamic> slot, int index) {
    int availablePoints = 0;
    List<Map<String, dynamic>> availablePointsList = [];

    if (slot['charging_points'] != null) {
      for (var point in slot['charging_points']) {
        if (point['status'] == 'available') {
          availablePoints++;
          availablePointsList.add(point);
        }
      }
    }

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
                  slot['time'],
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
                    color: availablePoints > 0
                        ? Colors.green.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$availablePoints/5 Available',
                    style: TextStyle(
                      color: availablePoints > 0 ? Colors.green : Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: 5,
              itemBuilder: (context, pointIndex) {
                final point = slot['charging_points'] != null &&
                        pointIndex < slot['charging_points'].length
                    ? slot['charging_points'][pointIndex]
                    : null;

                final isAvailable = point != null && point['status'] == 'available';
                final isSelected = selectedPointId == point?['id'].toString();

                return GestureDetector(
                  onTap: isAvailable
                      ? () {
                          setState(() {
                            selectedPointId = point['id'].toString();
                            selectedSlotTime = slot['time'];
                            selectedSlotId = slot['id'];
                          });
                        }
                      : null,
                  child: Container(
                    decoration: BoxDecoration(
                      color: _getPointColor(point),
                      borderRadius: BorderRadius.circular(8),
                      border: isSelected
                          ? Border.all(color: const Color(0xFF0033AA), width: 2)
                          : null,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Point ${pointIndex + 1}',
                            style: TextStyle(
                              color: isAvailable ? Colors.white : Colors.black54,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (point != null && point['status'] == 'maintenance')
                            Text(
                              point['maintenance_note'] ?? 'Maintenance',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            if (selectedPointId != null && selectedPointId == slot['charging_points'][0]['id'].toString())
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : () => _proceedToVehicleDetails(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0033AA),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('Book Point 3', style: TextStyle(fontSize: 18)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _proceedToVehicleDetails() async {
    if (selectedPointId == null || selectedSlotTime == null || selectedSlotId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a charging point'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VehicleDetailsScreen(
            stationId: widget.stationId,
            slotTime: selectedSlotTime!,
            selectedDate: widget.selectedDate,
            slotId: selectedSlotId!,
            pointId: selectedPointId!,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
