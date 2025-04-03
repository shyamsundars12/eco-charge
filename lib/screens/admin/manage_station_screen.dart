import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:ecocharge/screens/admin/location_selection_screen.dart';

class ManageStationScreen extends StatefulWidget {
  @override
  _ManageStationScreenState createState() => _ManageStationScreenState();
}

class _ManageStationScreenState extends State<ManageStationScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  LatLng? _selectedLocation;
  String? _selectedAddress;
  bool _isLoading = false;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text('Manage Stations'),
        backgroundColor: Color(0xFF0033AA),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.search),
            onPressed: () {
              showSearch(
                context: context,
                delegate: StationSearchDelegate(),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddStationDialog(context),
        backgroundColor: Color(0xFF0033AA),
        foregroundColor: Colors.white,
        icon: Icon(Icons.add, color: Colors.white), // Use 'icon:' instead of 'child:'
        label: Text('Add Station'),
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('ev_stations').orderBy('created_at', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.red),
                  SizedBox(height: 16),
                  Text(
                    'Error: ${snapshot.error}',
                    style: TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Loading stations...',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          final stations = snapshot.data!.docs;
          if (stations.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.ev_station, size: 64, color: Colors.grey[400]),
                  SizedBox(height: 16),
                  Text(
                    'No stations found',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Add your first station by tapping the button below',
                    style: TextStyle(color: Colors.grey[500]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return GridView.builder(
            padding: EdgeInsets.all(16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: MediaQuery.of(context).size.width > 600 ? 2 : 1,
              childAspectRatio: 0.85,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: stations.length,
            itemBuilder: (context, index) {
              final station = stations[index];
              final data = station.data() as Map<String, dynamic>;
              final location = data['location'] as GeoPoint?;
              final latLng = location != null 
                  ? LatLng(location.latitude, location.longitude)
                  : null;

              return Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: InkWell(
                  onTap: () => _showEditStationDialog(context, station),
                  borderRadius: BorderRadius.circular(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (latLng != null)
                        Expanded(
                          flex: 2,
                          child: ClipRRect(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                            child: Stack(
                              children: [
                                GoogleMap(
                                  initialCameraPosition: CameraPosition(
                                    target: latLng,
                                    zoom: 15,
                                  ),
                                  markers: {
                                    Marker(
                                      markerId: MarkerId(station.id),
                                      position: latLng,
                                      infoWindow: InfoWindow(
                                        title: data['name'] ?? 'Station',
                                        snippet: data['address'],
                                      ),
                                    ),
                                  },
                                  onMapCreated: (controller) {
                                    _mapController = controller;
                                  },
                                  zoomControlsEnabled: false,
                                  mapToolbarEnabled: false,
                                  myLocationButtonEnabled: false,
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 4,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.ev_station,
                                          size: 16,
                                          color: Color(0xFF0033AA),
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          data['charging_type'] ?? 'N/A',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      Expanded(
                        flex: 3,
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data['name'] ?? 'Unnamed Station',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: 8),
                              Text(
                                data['address'] ?? 'No address',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildInfoChip(
                                    Icons.power,
                                    '${data['slots'] ?? '0'} slots',
                                  ),
                                  _buildInfoChip(
                                    Icons.currency_rupee,
                                    '${data['price_per_kwh'] ?? '0'}/kWh',
                                  ),
                                ],
                              ),
                              Spacer(),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  _buildActionButton(
                                    icon: Icons.edit,
                                    color: Colors.orange,
                                    onPressed: () => _showEditStationDialog(context, station),
                                  ),
                                  _buildActionButton(
                                    icon: Icons.location_on,
                                    color: Colors.blue,
                                    onPressed: () => _showChangeLocationDialog(context, station),
                                  ),
                                  _buildActionButton(
                                    icon: Icons.delete,
                                    color: Colors.red,
                                    onPressed: () => _deleteStation(station.id),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Color(0xFF0033AA)),
          SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: IconButton(
        icon: Icon(icon, color: color),
        onPressed: onPressed,
        tooltip: icon == Icons.edit
            ? 'Edit Station'
            : icon == Icons.location_on
                ? 'Change Location'
                : 'Delete Station',
      ),
    );
  }

  Future<void> _showAddStationDialog(BuildContext context) async {
    final nameController = TextEditingController();
    final slotsController = TextEditingController();
    final priceController = TextEditingController();
    final addressController = TextEditingController();
    final ownerEmailController = TextEditingController();
    String selectedType = 'AC';
    bool availability = true;
    LatLng? selectedLocation;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Add New Station'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Station Name',
                    prefixIcon: Icon(Icons.ev_station),
                  ),
                ),
                TextField(
                  controller: ownerEmailController,
                  decoration: InputDecoration(
                    labelText: 'Owner Email',
                    prefixIcon: Icon(Icons.email),
                  ),
                ),
                TextField(
                  controller: slotsController,
                  decoration: InputDecoration(
                    labelText: 'Number of Slots',
                    prefixIcon: Icon(Icons.power),
                  ),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: priceController,
                  decoration: InputDecoration(
                    labelText: 'Price per kWh',
                    prefixIcon: Icon(Icons.currency_rupee),
                  ),
                  keyboardType: TextInputType.number,
                ),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: InputDecoration(
                    labelText: 'Charging Type',
                    prefixIcon: Icon(Icons.electrical_services),
                  ),
                  items: ['AC', 'DC'].map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type),
                    );
                  }).toList(),
                  onChanged: (value) {
                    selectedType = value!;
                  },
                ),
                SwitchListTile(
                  title: Text('Availability'),
                  value: availability,
                  onChanged: (value) {
                    setState(() => availability = value);
                  },
                ),
                SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: addressController,
                        decoration: InputDecoration(
                          labelText: 'Address',
                          prefixIcon: Icon(Icons.location_city),
                          suffixIcon: IconButton(
                            icon: Icon(Icons.location_on),
                            onPressed: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const LocationSelectionScreen(),
                                ),
                              );

                              if (result != null) {
                                setState(() {
                                  selectedLocation = result['location'];
                                  addressController.text = result['address'];
                                });
                              }
                            },
                            tooltip: 'Choose Location on Map',
                          ),
                        ),
                        readOnly: true,
                        maxLines: 2,
                      ),
                    ),
                  ],
                ),
                if (selectedLocation != null) ...[
                  SizedBox(height: 16),
                  Container(
                    height: 200,
                    child: GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: selectedLocation!,
                        zoom: 15,
                      ),
                      markers: {
                        Marker(
                          markerId: MarkerId('selected'),
                          position: selectedLocation!,
                          infoWindow: InfoWindow(
                            title: 'Selected Location',
                            snippet: addressController.text,
                          ),
                        ),
                      },
                      onMapCreated: (controller) {
                        _mapController = controller;
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isEmpty ||
                    slotsController.text.isEmpty ||
                    priceController.text.isEmpty ||
                    addressController.text.isEmpty ||
                    ownerEmailController.text.isEmpty ||
                    selectedLocation == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Please fill all fields and select a location')),
                  );
                  return;
                }

                try {
                  final docRef = await _firestore.collection('ev_stations').add({
                    'name': nameController.text,
                    'address': addressController.text,
                    'availability': availability,
                    'charging_type': selectedType,
                    'created_at': FieldValue.serverTimestamp(),
                    'latitude': selectedLocation!.latitude,
                    'longitude': selectedLocation!.longitude,
                    'location': GeoPoint(
                      selectedLocation!.latitude,
                      selectedLocation!.longitude,
                    ),
                    'owner_email': ownerEmailController.text,
                    'price_per_kwh': double.parse(priceController.text),
                    'slots': int.parse(slotsController.text),
                    'updated_at': FieldValue.serverTimestamp(),
                  });

                  // Update the document with its own ID
                  await docRef.update({
                    'station_id': docRef.id,
                  });

                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Station added successfully')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error adding station: $e')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF0033AA),
                foregroundColor: Colors.white,
              ),
              child: Text('Add Station'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showChangeLocationDialog(BuildContext context, DocumentSnapshot station) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const LocationSelectionScreen(),
      ),
    );

    if (result != null) {
      setState(() => _isLoading = true);
      try {
        await _firestore.collection('ev_stations').doc(station.id).update({
          'location': GeoPoint(
            result['location'].latitude,
            result['location'].longitude,
          ),
          'address': result['address'],
          'updated_at': FieldValue.serverTimestamp(),
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Station location updated successfully')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating station location: $e')),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showEditStationDialog(BuildContext context, DocumentSnapshot station) async {
    final data = station.data() as Map<String, dynamic>;
    final nameController = TextEditingController(text: data['name']);
    final slotsController = TextEditingController(text: data['slots']?.toString());
    final priceController = TextEditingController(text: data['price_per_kwh']?.toString());
    final addressController = TextEditingController(text: data['address']);
    final ownerEmailController = TextEditingController(text: data['owner_email']);
    String selectedType = data['charging_type'] ?? 'AC';
    bool availability = data['availability'] ?? true;
    LatLng? selectedLocation;
    if (data['location'] != null) {
      final location = data['location'] as GeoPoint;
      selectedLocation = LatLng(location.latitude, location.longitude);
    }

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Edit Station'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(labelText: 'Station Name'),
                ),
                TextField(
                  controller: ownerEmailController,
                  decoration: InputDecoration(labelText: 'Owner Email'),
                ),
                TextField(
                  controller: slotsController,
                  decoration: InputDecoration(labelText: 'Number of Slots'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: priceController,
                  decoration: InputDecoration(labelText: 'Price per kWh'),
                  keyboardType: TextInputType.number,
                ),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: InputDecoration(labelText: 'Charging Type'),
                  items: ['AC', 'DC'].map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type),
                    );
                  }).toList(),
                  onChanged: (value) {
                    selectedType = value!;
                  },
                ),
                SwitchListTile(
                  title: Text('Availability'),
                  value: availability,
                  onChanged: (value) {
                    setState(() => availability = value);
                  },
                ),
                SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: addressController,
                        decoration: InputDecoration(
                          labelText: 'Address',
                          suffixIcon: IconButton(
                            icon: Icon(Icons.location_on),
                            onPressed: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const LocationSelectionScreen(),
                                ),
                              );

                              if (result != null) {
                                setState(() {
                                  selectedLocation = result['location'];
                                  addressController.text = result['address'];
                                });
                              }
                            },
                            tooltip: 'Choose Location on Map',
                          ),
                        ),
                        readOnly: true,
                        maxLines: 2,
                      ),
                    ),
                  ],
                ),
                if (selectedLocation != null) ...[
                  SizedBox(height: 16),
                  Container(
                    height: 200,
                    child: GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: selectedLocation!,
                        zoom: 15,
                      ),
                      markers: {
                        Marker(
                          markerId: MarkerId('selected'),
                          position: selectedLocation!,
                          infoWindow: InfoWindow(
                            title: 'Selected Location',
                            snippet: addressController.text,
                          ),
                        ),
                      },
                      onMapCreated: (controller) {
                        _mapController = controller;
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  final updates = {
                    'name': nameController.text,
                    'owner_email': ownerEmailController.text,
                    'slots': int.tryParse(slotsController.text) ?? 0,
                    'price_per_kwh': double.tryParse(priceController.text) ?? 0.0,
                    'charging_type': selectedType,
                    'availability': availability,
                    'updated_at': FieldValue.serverTimestamp(),
                  };

                  if (selectedLocation != null) {
                    updates['location'] = GeoPoint(
                      selectedLocation!.latitude,
                      selectedLocation!.longitude,
                    );
                    updates['address'] = addressController.text;
                    updates['latitude'] = selectedLocation!.latitude;
                    updates['longitude'] = selectedLocation!.longitude;
                  }

                  await _firestore.collection('ev_stations').doc(station.id).update(updates);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Station updated successfully')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error updating station: $e')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF0033AA),
                foregroundColor: Colors.white,
              ),
              child: Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteStation(String stationId) async {
    try {
      await _firestore.collection('ev_stations').doc(stationId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Station deleted successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting station: $e')),
      );
    }
  }
}

class StationSearchDelegate extends SearchDelegate<String> {
  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.arrow_back),
      onPressed: () {
        close(context, '');
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults();
  }

  Widget _buildSearchResults() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('ev_stations')
          .where('name', isGreaterThanOrEqualTo: query)
          .where('name', isLessThanOrEqualTo: query + '\uf8ff')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        final stations = snapshot.data!.docs;
        if (stations.isEmpty) {
          return Center(
            child: Text('No stations found'),
          );
        }

        return ListView.builder(
          itemCount: stations.length,
          itemBuilder: (context, index) {
            final station = stations[index];
            final data = station.data() as Map<String, dynamic>;
            return ListTile(
              leading: Icon(Icons.ev_station, color: Color(0xFF0033AA)),
              title: Text(data['name'] ?? 'Unnamed Station'),
              subtitle: Text(data['address'] ?? 'No address'),
              onTap: () {
                close(context, station.id);
              },
            );
          },
        );
      },
    );
  }
} 