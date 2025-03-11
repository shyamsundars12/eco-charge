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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Please fill in all fields!")));
      return;
    }

    DocumentReference newStation = stations.doc(); // Generate a unique ID

    await newStation.set({
      'station_id': newStation.id, // Store the station ID
      'name': _nameController.text,
      'latitude': double.tryParse(_latitudeController.text) ?? 0.0,
      'longitude': double.tryParse(_longitudeController.text) ?? 0.0,
      'availability': true,
      'price_per_kwh': double.tryParse(_priceController.text) ?? 0.0,
      'owner_email': _ownerEmailController.text.trim(), // Store Owner Email
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

  void showAddStationDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Add New EV Station", style: TextStyle(fontWeight: FontWeight.bold)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTextField(_nameController, "Station Name", Icons.ev_station),
                _buildTextField(_latitudeController, "Latitude", Icons.map, isNumber: true),
                _buildTextField(_longitudeController, "Longitude", Icons.pin_drop, isNumber: true),
                _buildTextField(_priceController, "Price per kWh", Icons.attach_money, isNumber: true),
                _buildTextField(_ownerEmailController, "Owner Email", Icons.email), // New field
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancel")),
            ElevatedButton(
              onPressed: () {
                addStation();
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: Text("Add", style: TextStyle(color: Colors.white)),
            )
          ],
        );
      },
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, IconData icon, {bool isNumber = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: TextField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: hint,
          prefixIcon: Icon(icon, color: Colors.green),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Manage Stations")),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: showAddStationDialog,
        label: Text("Add Station"),
        icon: Icon(Icons.add),
        backgroundColor: Colors.blue,
      ),
      body: StreamBuilder(
        stream: stations.snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                "No stations available",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.grey),
              ),
            );
          }

          return ListView(
            padding: EdgeInsets.all(10),
            children: snapshot.data!.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>?;

              return Card(
                elevation: 4,
                margin: EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: EdgeInsets.all(15),
                  leading: Icon(Icons.ev_station, size: 40, color: Colors.blue),
                  title: Text(
                    data?['name'] ?? 'Unknown',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _infoRow(Icons.location_on, "Lat: ${data?['latitude'] ?? 'N/A'}"),
                        _infoRow(Icons.location_on_outlined, "Lng: ${data?['longitude'] ?? 'N/A'}"),
                        _infoRow(Icons.attach_money, "₹${data?['price_per_kwh'] ?? 'N/A'} per kWh"),
                        _infoRow(Icons.tag, "Station ID: ${data?['station_id'] ?? 'N/A'}"),
                        _infoRow(Icons.person, "Owner Email: ${data?['owner_email'] ?? 'N/A'}"), // Display Owner Email
                        _availabilityIndicator(data?['availability'] == true),
                      ],
                    ),
                  ),
                  trailing: IconButton(
                    icon: Icon(Icons.delete, color: Colors.blue),
                    onPressed: () => deleteStation(doc.id),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          SizedBox(width: 5),
          Text(text, style: TextStyle(fontSize: 14, color: Colors.grey[800])),
        ],
      ),
    );
  }

  Widget _availabilityIndicator(bool available) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(
            available ? Icons.check_circle : Icons.cancel,
            size: 18,
            color: available ? Colors.blue : Colors.blue,
          ),
          SizedBox(width: 5),
          Text(
            available ? "Available" : "Not Available",
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: available ? Colors.blue : Colors.blue),
          ),
        ],
      ),
    );
  }
}
