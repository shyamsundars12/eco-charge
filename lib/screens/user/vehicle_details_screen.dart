import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'payment_screen.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

class VehicleDetailsScreen extends StatefulWidget {
  final String stationId;
  final String slotTime;
  final String selectedDate;
  final String slotId;
  const VehicleDetailsScreen({
    Key? key,
    required this.stationId,
    required this.slotTime,
    required this.selectedDate,
    required this.slotId,
  }
  ) : super(key: key);

  @override
  _VehicleDetailsScreenState createState() => _VehicleDetailsScreenState();
}

class _VehicleDetailsScreenState extends State<VehicleDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final TextEditingController _vehicleNumberController = TextEditingController();
  final TextEditingController _vehicleModelController = TextEditingController();
  final TextEditingController _chargingCapacityController = TextEditingController();

  Future<void> _proceedToPayment() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        // Get current user
        final user = _auth.currentUser;
        if (user == null) throw Exception('User not logged in');

        // Get station details to calculate amount
        final stationDoc = await _firestore
            .collection('ev_stations')
            .doc(widget.stationId)
            .get();

        if (!stationDoc.exists) {
          throw Exception('Station not found');
        }

        final stationData = stationDoc.data() as Map<String, dynamic>;
        final pricePerKwh = stationData['price_per_kwh'] ?? 0.0;
        final chargingCapacity = double.parse(_chargingCapacityController.text);
        final amount = pricePerKwh * chargingCapacity;

        // Get slot details to verify status
        final slotDoc = await _firestore
            .collection('charging_slots')
            .doc(widget.stationId)
            .collection('slots')
            .doc(widget.slotId)
            .get();

        if (!slotDoc.exists) {
          throw Exception('Slot not found');
        }

        final slotData = slotDoc.data() as Map<String, dynamic>;
        if (slotData['status'] != 'pending') {
          throw Exception('This slot is no longer available');
        }

        // Create booking record
        DocumentReference bookingRef = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('bookings')
            .add({
          'station_id': widget.stationId,
          'slot_id': widget.slotId,
          'vehicle_number': _vehicleNumberController.text,
          'vehicle_model': _vehicleModelController.text,
          'charging_capacity': _chargingCapacityController.text,
          'amount': amount,
          'status': 'pending',
          'date': widget.selectedDate,
          'time': widget.slotTime,
          'created_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          // Navigate to payment screen
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PaymentScreen(
                stationId: widget.stationId,
                vehicleNumber: _vehicleNumberController.text,
                vehicleModel: _vehicleModelController.text,
                chargingCapacity: _chargingCapacityController.text,
                slotTime: widget.slotTime,
                amount: amount,
                bookingId: bookingRef.id,
                slotId: widget.slotId,
                date: widget.selectedDate,
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Enter Vehicle Details"),
        backgroundColor: const Color(0xFF0033AA),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Image.asset(
              'assets/images/vehicle_details.jpg',
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
            const SizedBox(height: 60),
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _vehicleNumberController,
                    decoration: const InputDecoration(
                      labelText: "Vehicle Number",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.directions_car),
                    ),
                    validator: (value) => value!.isEmpty ? "Enter vehicle number" : null,
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: _vehicleModelController,
                    decoration: const InputDecoration(
                      labelText: "Vehicle Model",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.electric_car),
                    ),
                    validator: (value) => value!.isEmpty ? "Enter vehicle model" : null,
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: _chargingCapacityController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Charging Capacity (kWh)",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.battery_charging_full),
                    ),
                    validator: (value) => value!.isEmpty ? "Enter charging capacity" : null,
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _proceedToPayment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0033AA),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        textStyle: const TextStyle(fontSize: 18),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.payment, color: Colors.white),
                          SizedBox(width: 8),
                          Text("Proceed to Payment"),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
