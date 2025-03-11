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
      appBar: AppBar(title: Text("Book Slot - ${widget.stationId}")), // ✅ Displays Station ID
      body: Column(
        children: [
          SizedBox(height: 10),
          buildDateSelector(),
          SizedBox(height: 10),
          Expanded(child: buildSlotGrid()), // ✅ Display slots dynamically
          if (selectedSlotTime.isNotEmpty) buildContinueButton(),
        ],
      ),
    );
  }

  /// ✅ Date Selector (Next 7 Days)
  Widget buildDateSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(7, (index) {
          DateTime date = DateTime.now().add(Duration(days: index));
          return GestureDetector(
            onTap: () => setState(() => selectedDate = date),
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 5),
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: selectedDate.day == date.day ? Colors.red : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey),
              ),
              child: Column(
                children: [
                  Text(DateFormat('E').format(date)), // Mon, Tue, etc.
                  Text("${date.day}", style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  /// ✅ Fetch Slots from Firestore & Display in Grid
  Widget buildSlotGrid() {
    String formattedDate = DateFormat('yyyy-MM-dd').format(selectedDate);
    print("Fetching slots for station: ${widget.stationId} on $formattedDate");

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('charging_slots') // ✅ Select Charging Slots Collection
          .doc(widget.stationId) // ✅ Get only slots for this Station
          .collection(formattedDate) // ✅ Get slots for selected Date
          .where('status', isEqualTo: 'available') // ✅ Only fetch available slots
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
        if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator());

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text("No available slots for this date."));
        }

        var slots = snapshot.data!.docs;

        return GridView.builder(
          padding: EdgeInsets.all(10),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            childAspectRatio: 2.5,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: slots.length,
          itemBuilder: (context, index) {
            var doc = slots[index];
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
            String slotTime = data['time'];

            return GestureDetector(
              onTap: () => setState(() => selectedSlotTime = slotTime),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: (selectedSlotTime == slotTime ? Colors.red : Colors.green),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  slotTime,
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// ✅ Book Slot Button
  Widget buildContinueButton() {
    return Padding(
      padding: EdgeInsets.all(10),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          minimumSize: Size(double.infinity, 50),
        ),
        onPressed: bookSlot,
        child: Text("Book Slot", style: TextStyle(color: Colors.white)),
      ),
    );
  }

  /// ✅ Book Slot in Firestore
  Future<void> bookSlot() async {
    if (selectedSlotTime.isEmpty) return;

    String formattedDate = DateFormat('yyyy-MM-dd').format(selectedDate);
    DocumentReference slotRef = _firestore
        .collection('charging_slots')
        .doc(widget.stationId)
        .collection(formattedDate)
        .doc(selectedSlotTime);

    try {
      await slotRef.update({'status': 'booked'}); // ✅ Update Firestore
      setState(() => selectedSlotTime = "");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Slot booked successfully!")));
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to book slot: $error")));
    }
  }
}
