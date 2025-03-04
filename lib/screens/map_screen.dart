import 'package:ecocharge/screens/signup_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geocoding/geocoding.dart';

import '../main.dart';
import '../services/notification_service.dart';

class MapScreen extends StatefulWidget {
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? mapController;
  LatLng _initialPosition = LatLng(11.0243, 77.0028);
  Set<Marker> _markers = {};
  TextEditingController _searchController = TextEditingController();
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _getUserLocation();
    _loadEVStations();
  }

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

    if (mapController != null) {
      mapController!.animateCamera(
        CameraUpdate.newCameraPosition(CameraPosition(target: _initialPosition, zoom: 20)),
      );
    }
  }

  Future<void> _loadEVStations() async {
    QuerySnapshot stations = await FirebaseFirestore.instance.collection('ev_stations').get();
    setState(() {
      _markers = stations.docs.map((doc) {
        return Marker(
          markerId: MarkerId(doc.id),
          position: LatLng(doc['latitude'], doc['longitude']),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: InfoWindow(
            title: doc['name'],
            snippet: "\$${doc['price_per_kwh']}/kWh",
            onTap: () => _showStationDetails(doc),
          ),
        );
      }).toSet();
    });
  }

  void _showStationDetails(QueryDocumentSnapshot doc) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        height: 300, // Increased height of the bottom sheet
        decoration: BoxDecoration(
          color: Colors.white, // White background for a professional look
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Padding(
          padding: EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Center the heading
              Center(
                child: Text(
                  doc['name'],
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              SizedBox(height: 40),
              // Price text with left padding
              Padding(
                padding: EdgeInsets.only(left: 20),
                child: Text(
                  "Price: \$${doc['price_per_kwh']}/kWh",
                  style: TextStyle(fontSize: 16, color: Colors.black),
                ),
              ),
              SizedBox(height: 20),
              // Availability text with left padding
              Padding(
                padding: EdgeInsets.only(left: 20),
                child: Text(
                  "Availability: ${doc['availability'] ? 'Available' : 'Not Available'}",
                  style: TextStyle(fontSize: 16, color: Colors.black),
                ),
              ),
              Spacer(), // Pushes the button to the bottom
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    NotificationService().showBookingNotification("Peelamedu");
                    print("Booking successful!");
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/vehicleDetails', arguments: doc.id);
                  },
                  child: Text("Book Now"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF0033AA),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }



  Future<void> _searchLocation() async {
    String query = _searchController.text;
    if (query.isEmpty) return;
    try {
      List<Location> locations = await locationFromAddress(query);
      if (locations.isNotEmpty) {
        Location location = locations.first;
        LatLng newPosition = LatLng(location.latitude, location.longitude);
        if (mapController != null) {
          mapController!.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(target: newPosition, zoom: 14)));
        }
        setState(() {
          _markers.add(
            Marker(
              markerId: MarkerId("search_marker"),
              position: newPosition,
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
            ),
          );
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Location not found! Try again.")),
      );
    }
  }

  void _onTabTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _buildCurrentScreen() {
    switch (_selectedIndex) {
      case 0:
        return Container(
          padding: EdgeInsets.all(8.0),
          height: MediaQuery.of(context).size.height * 0.75,
          child: GoogleMap(
            initialCameraPosition: CameraPosition(target: _initialPosition, zoom: 14),
            onMapCreated: (GoogleMapController controller) {
              setState(() {
                mapController = controller;
              });
            },
            myLocationEnabled: true,
            markers: _markers,
          ),
        );
      case 1:
        return Center(child: Text("📅 My Bookings"));
      case 2:
        return Center(child: Text("📞 Contact Us"));
      case 3:
        return Center(child: Text("👤 Account"));
      default:
        return Center(child: Text("⚡ More Features Coming Soon!"));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Find EV Stations"),
        backgroundColor: Color(0xFF0033AA),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white), // Back arrow
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context); // ✅ Goes back if possible
            } else {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => ArrivalScreen()), // Redirect if no back screen
              );
            }
          },
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => SignupScreen()),
              );
            },
          ),
        ],
      ),

      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(10.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: "Search location...",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                        icon: Icon(Icons.clear),
                        onPressed: () => setState(() => _searchController.clear()),
                      )
                          : null,
                    ),
                  ),
                ),
                SizedBox(width: 10),
                IconButton(
                  icon: Icon(Icons.search, color: Colors.blue, size: 30),
                  onPressed: _searchLocation,
                ),
              ],
            ),
          ),
          Expanded(child: _buildCurrentScreen()),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        currentIndex: _selectedIndex,
        onTap: _onTabTapped,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.map), label: "Map"),
          BottomNavigationBarItem(icon: Icon(Icons.book), label: "Bookings"),
          BottomNavigationBarItem(icon: Icon(Icons.contact_mail), label: "Contact"),
          BottomNavigationBarItem(icon: Icon(Icons.account_box), label: "Account"),
        ],
      ),
    );
  }
}
