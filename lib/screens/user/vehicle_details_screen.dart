import 'package:flutter/material.dart';

class VehicleDetailsScreen extends StatefulWidget {
  final String stationId;
  const VehicleDetailsScreen({Key? key, required this.stationId}) : super(key: key);

  @override
  _VehicleDetailsScreenState createState() => _VehicleDetailsScreenState();
}

class _VehicleDetailsScreenState extends State<VehicleDetailsScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _vehicleNumberController = TextEditingController();
  final TextEditingController _vehicleModelController = TextEditingController();
  final TextEditingController _chargingCapacityController = TextEditingController();

  void _proceedToPayment() {
    if (_formKey.currentState!.validate()) {
      Navigator.pushNamed(
        context,
        '/payment',
        arguments: {
          'stationId': widget.stationId,
          'vehicleNumber': _vehicleNumberController.text,
          'vehicleModel': _vehicleModelController.text,
          'chargingCapacity': _chargingCapacityController.text,
        },
      );
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // ✅ Added an Image (JPG format)
            Image.asset(
              'assets/images/vehicle_details.jpg',  // Ensure the image exists in assets
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
            ),

            const SizedBox(height: 60), // Spacing after image

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

                  // ✅ Proceed to Payment Button
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
