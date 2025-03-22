import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ManageStationsScreen extends StatefulWidget {
  @override
  _ManageStationsScreenState createState() => _ManageStationsScreenState();
}

class _ManageStationsScreenState extends State<ManageStationsScreen> {
  final CollectionReference stations =
  FirebaseFirestore.instance.collection('ev_stations');

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _latitudeController = TextEditingController();
  final TextEditingController _longitudeController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _ownerEmailController = TextEditingController();

  void addStation() async {
    if (_nameController.text.isEmpty ||
        _latitudeController.text.isEmpty ||
        _longitudeController.text.isEmpty ||
        _priceController.text.isEmpty ||
        _ownerEmailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Please fill in all fields!")));
      return;
    }

    DocumentReference newStation = stations.doc();
    await newStation.set({
      'station_id': newStation.id,
      'name': _nameController.text,
      'latitude': double.tryParse(_latitudeController.text) ?? 0.0,
      'longitude': double.tryParse(_longitudeController.text) ?? 0.0,
      'availability': true,
      'price_per_kwh': double.tryParse(_priceController.text) ?? 0.0,
      'owner_email': _ownerEmailController.text.trim(),
    });

    _nameController.clear();
    _latitudeController.clear();
    _longitudeController.clear();
    _priceController.clear();
    _ownerEmailController.clear();
  }

  void deleteStation(String id) {
    stations.doc(id).delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Manage Stations",
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Color(0xFF0033AA),
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddStationDialog(),
        label: Text("Add Station",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        icon: Icon(Icons.add, color: Colors.white),
        backgroundColor: Color(0xFF0033AA),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Color(0xFF0033AA),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Text(
                  "Manage EV Stations",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  "View, Add, and Remove Stations",
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder(
              stream: stations.snapshots(),
              builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text("No stations available",
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey)),
                  );
                }

                return ListView(
                  physics: BouncingScrollPhysics(),
                  padding: EdgeInsets.all(12),
                  children: snapshot.data!.docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>?;
                    return _buildStationCard(data, doc.id);
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildTextField(
      TextEditingController controller, String hint, IconData icon,
      {bool isNumber = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: hint,
          prefixIcon: Icon(icon, color: Color(0xFF0033AA)),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.grey[100],
        ),
      ),
    );
  }

  Widget _buildStationCard(Map<String, dynamic>? data, String id) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Card(
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: ListTile(
          contentPadding: EdgeInsets.symmetric(vertical: 15, horizontal: 15),
          leading: CircleAvatar(
            backgroundColor: Colors.blue[50],
            child: Icon(Icons.ev_station, color: Color(0xFF0033AA), size: 30),
          ),
          title: Text(
            data?['name'] ?? 'Unknown',
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0033AA)),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 5),
              _infoRow(Icons.location_on, "Lat: ${data?['latitude'] ?? 'N/A'}"),
              _infoRow(Icons.pin_drop, "Lng: ${data?['longitude'] ?? 'N/A'}"),
              _infoRow(Icons.currency_rupee,
                  "${data?['price_per_kwh'] ?? 'N/A'} per kWh"),
              _infoRow(Icons.person, "Owner: ${data?['owner_email'] ?? 'N/A'}"),
            ],
          ),
          trailing: IconButton(
            icon: Icon(Icons.delete, color: Colors.red),
            onPressed: () => deleteStation(id),
          ),
          isThreeLine: true, // Ensures space for extra text
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Color(0xFF0033AA)),
        SizedBox(width: 6),
        Expanded( // Prevents overflow
          child: Text(text,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: TextStyle(fontSize: 14, color: Colors.black87)),
        ),
      ],
    );
  }

  void _showAddStationDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            "Add New EV Station",
            style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0033AA)),
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTextField(_nameController, "Station Name", Icons.ev_station),
                _buildTextField(_latitudeController, "Latitude", Icons.map, isNumber: true),
                _buildTextField(_longitudeController, "Longitude", Icons.pin_drop, isNumber: true),
                _buildTextField(_priceController, "Price per kWh", Icons.attach_money, isNumber: true),
                _buildTextField(_ownerEmailController, "Owner Email", Icons.email),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                addStation();
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF0033AA),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8))),
              child: Text("Add", style: TextStyle(color: Colors.white)),
            )
          ],
        );
      },
    );
  }
}
