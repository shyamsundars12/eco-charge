import 'package:ecocharge/screens/user/vehicle_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class SlotBookingScreen extends StatefulWidget {
  final String stationId;
  SlotBookingScreen({required this.stationId});

  @override
  _SlotBookingScreenState createState() => _SlotBookingScreenState();
}

class _SlotBookingScreenState extends State<SlotBookingScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  DateTime selectedDate = DateTime.now();
  String selectedSlotTime = "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("Book Slot - ${widget.stationId}", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Color(0xFF0033AA),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          SizedBox(height: 20), // Increased space above Date Selector
          buildDateSelector(),
          SizedBox(height: 50), // Increased space between Date Selector & Slots
          Expanded(child: buildSlotGrid()),
          if (selectedSlotTime.isNotEmpty) SizedBox(height: 20), // Space before Button
          if (selectedSlotTime.isNotEmpty) buildContinueButton(),
        ],
      ),

    );
  }

  /// ✅ Modernized Date Selector
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

  /// ✅ Fetch Slots & Display with Updated Colors
  Widget buildSlotGrid() {
    String formattedDate = DateFormat('yyyy-MM-dd').format(selectedDate);

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('charging_slots')
          .doc(widget.stationId)
          .collection(formattedDate)
          .where('status', isEqualTo: 'available')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}", style: TextStyle(color: Colors.red)));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: Color(0xFF0033AA)));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 50),
              child: Text(
                "No available slots for this date.",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0033AA)),
              ),
            ),
          );
        }

        var slots = snapshot.data!.docs;

        return Center(
          child: GridView.builder(
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
                    boxShadow: [
                      BoxShadow(color: Colors.black12, blurRadius: 5, offset: Offset(0, 3))
                    ],
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
          ),
        );
      },
    );
  }

  /// ✅ Improved "Book Slot" Button with Your Colors
  Widget buildContinueButton() {
    return Padding(
      padding: EdgeInsets.all(15),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Color(0xFF0033AA), // ✅ Blue Background
          foregroundColor: Colors.white, // ✅ White Text
          minimumSize: Size(double.infinity, 55),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          shadowColor: Colors.white.withOpacity(0.4),
          elevation: 6,
        ),
        onPressed: bookSlot,
        child: Text("Book Slot", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }

  /// ✅ Book Slot with Themed Snackbar
  Future<void> bookSlot() async {
    if (selectedSlotTime.isEmpty) return;

    String formattedDate = DateFormat('yyyy-MM-dd').format(selectedDate);
    DocumentReference slotRef = _firestore
        .collection('charging_slots')
        .doc(widget.stationId)
        .collection(formattedDate)
        .doc(selectedSlotTime);

    try {
      await slotRef.update({'status': 'booked'});
      setState(() => selectedSlotTime = "");

      // Show SnackBar for Success
      /*ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Slot booked successfully!", style: TextStyle(fontSize: 16, color: Colors.white)),
          backgroundColor: Color(0xFF0033AA),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );*/

      // Navigate to VehicleDetailsScreen after a slight delay
      Future.delayed(Duration(milliseconds: 500), () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VehicleDetailsScreen(stationId: widget.stationId),
          ),
        );
      });
    } catch (error) {
      // Show Error SnackBar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to book slot: $error", style: TextStyle(fontSize: 16, color: Colors.white)),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

}
