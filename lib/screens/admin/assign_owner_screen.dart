import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AssignOwnerScreen extends StatefulWidget {
  @override
  _AssignOwnerScreenState createState() => _AssignOwnerScreenState();
}

class _AssignOwnerScreenState extends State<AssignOwnerScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? selectedStationId;
  final TextEditingController _ownerNameController = TextEditingController();
  final TextEditingController _ownerEmailController = TextEditingController();
  final TextEditingController _ownerPasswordController = TextEditingController();

  Future<void> assignStationToOwner() async {
    if (_ownerNameController.text.isEmpty ||
        _ownerEmailController.text.isEmpty ||
        _ownerPasswordController.text.isEmpty ||
        selectedStationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please fill in all fields.")),
      );
      return;
    }

    try {
      // Create Owner in Firebase Authentication
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: _ownerEmailController.text.trim(),
        password: _ownerPasswordController.text.trim(),
      );

      String ownerId = userCredential.user!.uid;

      // Store owner details in Firestore
      await _firestore.collection('ev_owners').doc(ownerId).set({
        'owner_id': ownerId,
        'name': _ownerNameController.text.trim(),
        'email': _ownerEmailController.text.trim(),
        'stations': [selectedStationId],
      });

      // Assign owner to station in Firestore
      await _firestore.collection('ev_stations').doc(selectedStationId).update({
        'owner_id': ownerId,
        'owner_email': _ownerEmailController.text.trim(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Owner assigned successfully!")),
      );

      // Clear fields
      setState(() {
        _ownerNameController.clear();
        _ownerEmailController.clear();
        _ownerPasswordController.clear();
        selectedStationId = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Assign EV Station to Owner")),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Enter Owner Details", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            _buildTextField(_ownerNameController, "Owner Name", Icons.person),
            _buildTextField(_ownerEmailController, "Owner Email", Icons.email),
            _buildTextField(_ownerPasswordController, "Password", Icons.lock, obscureText: true),
            SizedBox(height: 20),
            Text("Select EV Station", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            StreamBuilder(
              stream: _firestore.collection('ev_stations').where('owner_id', isEqualTo: null).snapshots(),
              builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (!snapshot.hasData) return CircularProgressIndicator();
                return DropdownButton<String>(
                  value: selectedStationId,
                  isExpanded: true,
                  hint: Text("Select Station"),
                  items: snapshot.data!.docs.map((doc) {
                    return DropdownMenuItem<String>(
                      value: doc.id,
                      child: Text(doc['name']),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => selectedStationId = value);
                  },
                );
              },
            ),
            SizedBox(height: 30),
            ElevatedButton(
              onPressed: assignStationToOwner,
              child: Text("Assign Station"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, IconData icon, {bool obscureText = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        decoration: InputDecoration(
          labelText: hint,
          prefixIcon: Icon(icon, color: Colors.green),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}
