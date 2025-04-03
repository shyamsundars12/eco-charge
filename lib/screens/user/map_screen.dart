import 'package:ecocharge/screens/user/signup_screen.dart';
import 'package:ecocharge/screens/user/slot_booking_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart';

import '../../main.dart';
import 'my_bookings_screen.dart';
import 'package:ecocharge/screens/user/profile_screen.dart';
import 'package:ecocharge/screens/user/contact_screen.dart';
import 'package:ecocharge/screens/user/chatbot_screen.dart';

class MapScreen extends StatefulWidget {
  @override
  _MapScreenState createState() => _MapScreenState();
}

List<String> _searchSuggestions = [];

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? mapController;
  LatLng? _initialPosition;
  Set<Marker> _markers = {};
  TextEditingController _searchController = TextEditingController();
  int _selectedIndex = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    await _getUserLocation();
    await _loadEVStations();
  }

  Future<void> _getUserLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Location services are disabled. Please enable them.')),
        );
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Location permissions are denied. Please enable them in settings.')),
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Location permissions are permanently denied. Please enable them in settings.')),
        );
        return;
      }
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 5),
      );

      setState(() {
        _initialPosition = LatLng(position.latitude, position.longitude);
        _isLoading = false;
      });

      // Update map camera
      if (mapController != null) {
        mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: _initialPosition!,
              zoom: 13,
            ),
          ),
        );
      }
    } catch (e) {
      print('Error getting location: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error getting your location. Please try again.')),
      );
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchSuggestions(String query) async {
    if (query.isEmpty) {
      setState(() => _searchSuggestions = []);
      return;
    }
    try {
      QuerySnapshot stations = await FirebaseFirestore.instance
          .collection('ev_stations')
          .get();

      List<String> allStations = stations.docs.map((doc) => doc['name'].toString()).toList();

      setState(() {
        _searchSuggestions = allStations
            .where((name) => name.toLowerCase().contains(query.toLowerCase())) // 🔥 Case-insensitive search
            .toList();
      });
    } catch (e) {
      print("Error fetching suggestions: $e");
    }
  }

  Future<void> _loadEVStations() async {
    try {
      QuerySnapshot stations = await FirebaseFirestore.instance
          .collection('ev_stations')
          .get();

      if (stations.docs.isEmpty) {
        print("No EV stations found in Firestore!");
        return;
      }

      setState(() {
        _markers = stations.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return Marker(
            markerId: MarkerId(doc.id),
            position: LatLng(
              data['latitude'] ?? 0.0,
              data['longitude'] ?? 0.0,
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
            infoWindow: InfoWindow(
              title: data['name'] ?? 'Unknown Station',
              snippet: "₹${data['price_per_kwh'] ?? '0'}/kWh",
              onTap: () => _showStationDetails(doc.id, doc),
            ),
          );
        }).toSet();
      });
    } catch (e) {
      print("Error loading EV stations: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading charging stations. Please try again.')),
      );
    }
  }

  void _showStationDetails(String stationId, QueryDocumentSnapshot doc) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        height: 300,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Padding(
          padding: EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Text(
                  doc['name'],
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              SizedBox(height: 40),
              Padding(
                padding: EdgeInsets.only(left: 20),
                child: Text(
                  "Price: ₹${doc['price_per_kwh']}/kWh",
                  style: TextStyle(fontSize: 16, color: Colors.black),
                ),
              ),
              SizedBox(height: 20),
              Padding(
                padding: EdgeInsets.only(left: 20),
                child: Text(
                  "Availability: ${doc['availability'] ? 'Available' : 'Not Available'}",
                  style: TextStyle(fontSize: 16, color: Colors.black),
                ),
              ),
              Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SlotBookingScreen(
                          stationId: stationId,
                          stationName: doc['name'],
                          selectedDate: DateFormat('yyyy-MM-dd').format(DateTime.now()),
                        ),
                      ),
                    );
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

  Future<void> _searchLocation(String query) async {
    if (query.isEmpty) return;

    try {
      QuerySnapshot stations = await FirebaseFirestore.instance
          .collection('ev_stations')
          .where('name', isGreaterThanOrEqualTo: query)
          .where('name', isLessThan: query + '\uf8ff')
          .get();

      if (stations.docs.isNotEmpty) {
        var doc = stations.docs.first;
        LatLng stationLocation = LatLng(doc['latitude'], doc['longitude']);

        setState(() {
          _markers = {
            Marker(
              markerId: MarkerId(doc.id),
              position: stationLocation,
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
              infoWindow: InfoWindow(
                title: doc['name'],
                snippet: "₹${doc['price_per_kwh']}/kWh",
                onTap: () {
                  _showStationDetails(doc.id, doc); // ✅ Open booking when clicked
                },
              ),
            ),
          };
        });

        if (mapController != null) {
          mapController!.animateCamera(CameraUpdate.newCameraPosition(
            CameraPosition(target: stationLocation, zoom: 14),
          ));
        }
      }
    } catch (e) {
      print("Search error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error finding location.")),
      );
    }
  }

  void _onTabTapped(int index) {
    if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => MyBookingsScreen()),
      );
    } else if (index == 2) { // Contact tab
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ContactScreen()),
      );
    } else if (index == 3) { // Chatbot tab
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ChatbotScreen()),
      );
    } else if (index == 4) { // Profile tab
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ProfileScreen()),
      );
    } else {
      setState(() {
        _selectedIndex = index;
      });
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
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => ArrivalScreen()),
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
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _initialPosition == null
              ? Center(child: Text('Unable to get your location'))
              : Stack(
                  children: [
                    GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: _initialPosition!,
                        zoom: 13,
                      ),
                      onMapCreated: (GoogleMapController controller) {
                        mapController = controller;
                      },
                      markers: _markers,
                      myLocationEnabled: true,
                      myLocationButtonEnabled: true,
                      zoomControlsEnabled: true,
                      mapToolbarEnabled: true,
                    ),
                    Positioned(
                      top: 40,
                      left: 16,
                      right: 16,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.5),
                              spreadRadius: 1,
                              blurRadius: 5,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search for charging stations...',
                            prefixIcon: Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: EdgeInsets.symmetric(horizontal: 16),
                          ),
                          onChanged: (value) => _fetchSuggestions(value),
                          onSubmitted: _searchLocation,
                        ),
                      ),
                    ),
                    if (_searchSuggestions.isNotEmpty)
                      Positioned(
                        top: 100,
                        left: 16,
                        right: 16,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.5),
                                spreadRadius: 1,
                                blurRadius: 5,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: _searchSuggestions.length,
                            itemBuilder: (context, index) {
                              return ListTile(
                                title: Text(_searchSuggestions[index]),
                                onTap: () {
                                  _searchController.text = _searchSuggestions[index];
                                  _searchLocation(_searchSuggestions[index]);
                                  setState(() => _searchSuggestions = []);
                                },
                              );
                            },
                          ),
                        ),
                      ),
                  ],
                ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onTabTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Color(0xFF0033AA),
        unselectedItemColor: Colors.grey,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Map',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Bookings',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.contact_support),
            label: 'Contact',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat),
            label: 'Chat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
