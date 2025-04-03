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
  bool _isLoading = false;
  String? _errorMessage;
  late String _stationName;
  String? _userId;

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
          .where('status', isEqualTo: 'available')
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

        return GridView.builder(
          padding: EdgeInsets.all(20),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            childAspectRatio: 2.5,
            crossAxisSpacing: 15,
            mainAxisSpacing: 15,
          ),
          itemCount: slots.length,
          itemBuilder: (context, index) {
            var doc = slots[index];
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
            String slotTime = data['time'];
            bool isSelected = selectedSlotTime == slotTime;

            return GestureDetector(
              onTap: () => setState(() => selectedSlotTime = slotTime),
              child: AnimatedContainer(
                duration: Duration(milliseconds: 300),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? Color(0xFF0033AA) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Color(0xFF0033AA), width: 2),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5, offset: Offset(0, 3))],
                ),
                child: Text(
                  slotTime,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Color(0xFF0033AA),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
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
      if (selectedSlotTime.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please select a slot first'), backgroundColor: Colors.red),
        );
        return;
      }

      String formattedDate = DateFormat('yyyy-MM-dd').format(selectedDate);
      String slotId = "${formattedDate}_$selectedSlotTime";

      // Update the slot status to pending
      await _firestore
          .collection('charging_slots')
          .doc(widget.stationId)
          .collection('slots')
          .doc(slotId)
          .update({
        'status': 'pending',
        'pending_by': _userId,
        'date': formattedDate,
        'time': selectedSlotTime,
        'sort_key': slotId,
        'updated_at': FieldValue.serverTimestamp(),
      });

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VehicleDetailsScreen(
            stationId: widget.stationId,
            slotTime: selectedSlotTime,
            selectedDate: formattedDate,
            slotId: slotId,
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

      // Update the slot status to pending
      await _firestore
          .collection('charging_slots')
          .doc(widget.stationId)
          .collection('slots')
          .doc(slotId)
          .update({
        'status': 'pending',
        'pending_by': _userId,
        'date': formattedDate,
        'time': slotTime,
        'sort_key': slotId,
        'updated_at': FieldValue.serverTimestamp(),
      });

      if (context.mounted) {
        Navigator.pop(context); // Close the bottom sheet
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VehicleDetailsScreen(
              stationId: widget.stationId,
              slotTime: slotTime,
              selectedDate: formattedDate,
              slotId: slotId,
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error booking slot: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
