import 'package:flutter/material.dart';

class VehicleDetailsScreen extends StatefulWidget {
  final String stationId;
  VehicleDetailsScreen({required this.stationId});

  @override
  _VehicleDetailsScreenState createState() => _VehicleDetailsScreenState();
}

class _VehicleDetailsScreenState extends State<VehicleDetailsScreen> {
  final _formKey = GlobalKey<FormState>();

  TextEditingController _vehicleNumberController = TextEditingController();
  TextEditingController _vehicleModelController = TextEditingController();
  TextEditingController _chargingCapacityController = TextEditingController();

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
        title: Text("Enter Vehicle Details"),
        backgroundColor: Colors.green,
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _vehicleNumberController,
                decoration: InputDecoration(
                  labelText: "Vehicle Number",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.directions_car),
                ),
                validator: (value) => value!.isEmpty ? "Enter vehicle number" : null,
              ),
              SizedBox(height: 15),
              TextFormField(
                controller: _vehicleModelController,
                decoration: InputDecoration(
                  labelText: "Vehicle Model",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.electric_car),
                ),
                validator: (value) => value!.isEmpty ? "Enter vehicle model" : null,
              ),
              SizedBox(height: 15),
              TextFormField(
                controller: _chargingCapacityController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "Charging Capacity (kWh)",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.battery_charging_full),
                ),
                validator: (value) => value!.isEmpty ? "Enter charging capacity" : null,
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _proceedToPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: EdgeInsets.symmetric(vertical: 12),
                  textStyle: TextStyle(fontSize: 18),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.payment),
                    SizedBox(width: 8),
                    Text("Proceed to Payment"),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
