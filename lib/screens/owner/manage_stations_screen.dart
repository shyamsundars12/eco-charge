import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ManageStationsScreen extends StatefulWidget {
  @override
  _ManageStationsScreenState createState() => _ManageStationsScreenState();
}

class _ManageStationsScreenState extends State<ManageStationsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _ownerEmail;

  @override
  void initState() {
    super.initState();
    _ownerEmail = _auth.currentUser?.email;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Stations'),
        backgroundColor: Color(0xFF0033AA),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('ev_stations')
            .where('owner_email', isEqualTo: _ownerEmail)
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
                  Text('No stations found'),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Add station functionality coming soon')),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF0033AA),
                      foregroundColor: Colors.white,
                    ),
                    child: Text('Add New Station'),
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
                child: ExpansionTile(
                  title: Text(
                    data['name'] ?? 'Unnamed Station',
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
                  children: [
                    Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildInfoRow('Address', data['address'] ?? 'N/A'),
                          _buildInfoRow('Total Slots', data['total_slots']?.toString() ?? '0'),
                          _buildInfoRow('Available Slots', data['available_slots']?.toString() ?? '0'),
                          _buildInfoRow('Charging Types', _formatChargingTypes(data['charging_types'])),
                          _buildInfoRow('Price per kWh', '₹${data['price_per_kwh']?.toString() ?? '0.00'}'),
                          SizedBox(height: 16),
                          Center(
                            child: ElevatedButton(
                              onPressed: () => _showEditDialog(doc.id, data),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFF0033AA),
                                foregroundColor: Colors.white,
                              ),
                              child: Text('Edit'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showEditDialog(String docId, Map<String, dynamic> data) {
    TextEditingController nameController = TextEditingController(text: data['name']);
    TextEditingController addressController = TextEditingController(text: data['address']);
    TextEditingController slotsController = TextEditingController(text: data['total_slots']?.toString());
    TextEditingController priceController = TextEditingController(text: data['price_per_kwh']?.toString());

    String selectedStatus = data['status'] ?? 'active';
    List<String> statusOptions = ['active', 'inactive', 'maintenance'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Edit Station', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 16),
              _buildTextField(nameController, 'Station Name'),
              _buildTextField(addressController, 'Address'),
              _buildTextField(slotsController, 'Total Slots', isNumber: true),
              _buildTextField(priceController, 'Price per kWh', isNumber: true),
              DropdownButtonFormField(
                value: selectedStatus,
                items: statusOptions.map((status) {
                  return DropdownMenuItem(value: status, child: Text(status.toUpperCase()));
                }).toList(),
                onChanged: (value) => selectedStatus = value.toString(),
                decoration: InputDecoration(labelText: 'Status'),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  await _firestore.collection('ev_stations').doc(docId).update({
                    'name': nameController.text,
                    'address': addressController.text,
                    'total_slots': int.tryParse(slotsController.text) ?? 0,
                    'price_per_kwh': double.tryParse(priceController.text) ?? 0.0,
                    'status': selectedStatus,
                  });
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF0033AA), foregroundColor: Colors.white),
                child: Text('Save Changes'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, {bool isNumber = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'inactive':
        return Colors.red;
      case 'maintenance':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _formatChargingTypes(List<dynamic>? types) {
    if (types == null || types.isEmpty) return 'N/A';
    return types.join(', ');
  }
}
