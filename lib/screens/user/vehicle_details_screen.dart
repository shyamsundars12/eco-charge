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
  final String pointId;
  const VehicleDetailsScreen({
    Key? key,
    required this.stationId,
    required this.slotTime,
    required this.selectedDate,
    required this.slotId,
    required this.pointId,
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
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isLoading = true);

      try {
        // Get station details for price calculation
        DocumentSnapshot stationDoc = await _firestore
            .collection('ev_stations')
            .doc(widget.stationId)
            .get();

        if (!stationDoc.exists) {
          throw Exception('Station not found');
        }

        Map<String, dynamic> stationData = stationDoc.data() as Map<String, dynamic>;
        double pricePerKwh = (stationData['price_per_kwh'] as num?)?.toDouble() ?? 0.0;

        // Calculate amount based on charging capacity
        double chargingCapacity = double.parse(_chargingCapacityController.text);
        double amount = chargingCapacity * pricePerKwh;

        // Get slot details and verify charging point status
        DocumentSnapshot slotDoc = await _firestore
            .collection('charging_slots')
            .doc(widget.stationId)
            .collection('slots')
            .doc(widget.slotId)
            .get();

        if (!slotDoc.exists) {
          throw Exception('Slot not found');
        }

        Map<String, dynamic> slotData = slotDoc.data() as Map<String, dynamic>;
        List<dynamic> chargingPoints = List.from(slotData['charging_points'] ?? []);

        // Find and verify the selected charging point
        bool pointFound = false;
        for (int i = 0; i < chargingPoints.length; i++) {
          if (chargingPoints[i]['id'].toString() == widget.pointId) {
            if (chargingPoints[i]['status'] != 'pending' || chargingPoints[i]['pending_by'] != _auth.currentUser!.uid) {
              throw Exception('This charging point is no longer available for booking');
            }
            chargingPoints[i]['status'] = 'booked';
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
            .doc(widget.slotId)
            .update({
          'charging_points': chargingPoints,
          'updated_at': FieldValue.serverTimestamp(),
        });

        // Create booking record
        DocumentReference bookingRef = await _firestore.collection('bookings').add({
          'user_id': _auth.currentUser!.uid,
          'station_id': widget.stationId,
          'slot_id': widget.slotId,
          'point_id': widget.pointId,
          'vehicle_number': _vehicleNumberController.text,
          'vehicle_model': _vehicleModelController.text,
          'charging_capacity': chargingCapacity,
          'amount': amount,
          'status': 'pending',
          'date': widget.selectedDate,
          'time': widget.slotTime,
          'created_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        });

        // Navigate to payment screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PaymentScreen(
              bookingId: bookingRef.id,
              amount: amount,
              stationId: widget.stationId,
              slotId: widget.slotId,
              pointId: widget.pointId,
              vehicleNumber: _vehicleNumberController.text,
              vehicleModel: _vehicleModelController.text,
              chargingCapacity: _chargingCapacityController.text,
              slotTime: widget.slotTime,
              date: widget.selectedDate,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vehicle Details'),
        backgroundColor: const Color(0xFF0033AA),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _isLoading ? null : () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Image.asset(
                      'assets/images/vehicle_details.jpg',
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                    const SizedBox(height: 60),
                    TextFormField(
                      controller: _vehicleNumberController,
                      decoration: const InputDecoration(
                        labelText: 'Vehicle Number',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter vehicle number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _vehicleModelController,
                      decoration: const InputDecoration(
                        labelText: 'Vehicle Model',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter vehicle model';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _chargingCapacityController,
                      decoration: const InputDecoration(
                        labelText: 'Charging Capacity (kWh)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter charging capacity';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Please enter a valid number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _proceedToPayment,
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
                            : const Text('Proceed to Payment', style: TextStyle(fontSize: 18)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
