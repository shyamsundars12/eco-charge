import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../main.dart'; // Ensure ArrivalScreen() exists in main.dart or correct the import

class MapScreen extends StatefulWidget {
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late GoogleMapController mapController;
  LatLng _initialPosition = LatLng(37.7749, -122.4194); // Default: San Francisco
  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _getUserLocation();
    _loadEVStations();
  }

  // ✅ Get User's Current Location
  Future<void> _getUserLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

    setState(() {
      _initialPosition = LatLng(position.latitude, position.longitude);
    });

    mapController.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: _initialPosition, zoom: 14),
      ),
    );
  }

  // ✅ Load EV Stations from Firestore
  Future<void> _loadEVStations() async {
    QuerySnapshot stations = await FirebaseFirestore.instance.collection('ev_stations').get();

    setState(() {
      _markers = stations.docs.map((doc) {
        return Marker(
          markerId: MarkerId(doc.id),
          position: LatLng(doc['latitude'], doc['longitude']),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(
            title: doc['name'],
            snippet: "\$${doc['price_per_kwh']}/kWh",
            onTap: () => _showStationDetails(doc),
          ),
        );
      }).toSet();
    });
  }

  // ✅ Show EV Station Details Popup
  void _showStationDetails(QueryDocumentSnapshot doc) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(doc['name']),
        content: Text(
          "Price: \$${doc['price_per_kwh']}/kWh\n"
              "Availability: ${doc['availability'] ? 'Available' : 'Not Available'}",
        ),
        actions: [
          TextButton(
            child: Text("Book Now"),
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/booking', arguments: doc.id);
            },
          ),
        ],
      ),
    );
  }

  // ✅ Logout Function
  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => ArrivalScreen()), // Ensure ArrivalScreen exists
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Find EV Stations"),
        actions: [
          IconButton(
            icon: Icon(Icons.logout, color: Colors.white),
            onPressed: _logout, // Call the logout function
          ),
        ],
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(target: _initialPosition, zoom: 14),
        onMapCreated: (GoogleMapController controller) {
          setState(() => mapController = controller);
        },
        myLocationEnabled: true,
        markers: _markers,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _logout, // Call the logout function
        backgroundColor: Colors.redAccent,
        child: Icon(Icons.logout, color: Colors.green),
      ),
    );
  }
}
