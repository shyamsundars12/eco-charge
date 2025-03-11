import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StationOverviewScreen extends StatelessWidget {
  final CollectionReference stations = FirebaseFirestore.instance.collection('charging_stations');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Station Overview")),
      body: StreamBuilder(
        stream: stations.snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (!snapshot.hasData) return CircularProgressIndicator();
          return ListView(
            children: snapshot.data!.docs.map((doc) {
              return ListTile(title: Text(doc['name']), subtitle: Text("Chargers: ${doc['chargers']}"));
            }).toList(),
          );
        },
      ),
    );
  }
}
