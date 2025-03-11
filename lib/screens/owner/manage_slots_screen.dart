import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class ManageSlotsScreen extends StatefulWidget {
  @override
  _ManageSlotsScreenState createState() => _ManageSlotsScreenState();
}

class _ManageSlotsScreenState extends State<ManageSlotsScreen> {
  String? selectedStationId;
  String? ownerEmail;
  List<String> ownerStations = [];

  @override
  void initState() {
    super.initState();
    fetchOwnerStations();
  }

  Future<void> fetchOwnerStations() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        ownerEmail = user.email;
      });

      QuerySnapshot stationSnapshot = await FirebaseFirestore.instance
          .collection('ev_stations')
          .where('owner_email', isEqualTo: ownerEmail)
          .get();

      setState(() {
        ownerStations = stationSnapshot.docs.map((doc) => doc.id).toList();
        if (ownerStations.isNotEmpty) {
          selectedStationId = ownerStations.first;
        }
      });
    }
  }

  Future<void> generateSlots() async {
    if (selectedStationId == null) return;

    final firestore = FirebaseFirestore.instance;
    DateTime now = DateTime.now();

    for (int i = 0; i < 7; i++) {
      DateTime date = now.add(Duration(days: i));
      String formattedDate = DateFormat('yyyy-MM-dd').format(date);

      for (int hour = 8; hour < 20; hour++) {
        for (int min = 0; min < 60; min += 30) {
          String slotTime = "${hour.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}";

          await firestore
              .collection('charging_slots')
              .doc(selectedStationId)
              .collection(formattedDate)
              .doc(slotTime)
              .set({'time': slotTime, 'status': 'available'});
        }
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Slots generated successfully!")),
    );
  }

  void removeSlot(String date, String slotId) {
    FirebaseFirestore.instance
        .collection('charging_slots')
        .doc(selectedStationId)
        .collection(date)
        .doc(slotId)
        .delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Manage Charging Slots"),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Dropdown & Button Section
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Select EV Station:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    DropdownButton<String>(
                      value: selectedStationId,
                      isExpanded: true,
                      items: ownerStations.map((stationId) {
                        return DropdownMenuItem<String>(
                          value: stationId,
                          child: Text(stationId, style: TextStyle(fontSize: 14)),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedStationId = value;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: generateSlots,
                      icon: Icon(Icons.calendar_month, color: Colors.white),
                      label: Text("Generate Slots for 7 Days"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: EdgeInsets.symmetric(vertical: 12),
                        textStyle: TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Slots List Section
            Expanded(
              child: selectedStationId == null
                  ? Center(
                child: Text(
                  "No assigned EV stations found.",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.redAccent),
                ),
              )
                  : StreamBuilder(
                stream: FirebaseFirestore.instance
                    .collection('charging_slots')
                    .doc(selectedStationId)
                    .collection(DateFormat('yyyy-MM-dd').format(DateTime.now()))
                    .snapshots(),
                builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                  if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
                  if (snapshot.data!.docs.isEmpty) {
                    return Center(child: Text("No slots available for today."));
                  }

                  return ListView.builder(
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      var doc = snapshot.data!.docs[index];
                      return Card(
                        margin: EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 2,
                        child: ListTile(
                          leading: Icon(Icons.access_time, color: Colors.green),
                          title: Text(
                            doc['time'],
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          trailing: IconButton(
                            icon: Icon(Icons.delete, color: Colors.red),
                            onPressed: () => removeSlot(
                              DateFormat('yyyy-MM-dd').format(DateTime.now()),
                              doc.id,
                            ),
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
      ),
    );
  }
}
