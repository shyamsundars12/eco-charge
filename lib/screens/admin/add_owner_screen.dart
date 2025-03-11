import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttertoast/fluttertoast.dart';

class AddOwnerScreen extends StatefulWidget {
  @override
  _AddOwnerScreenState createState() => _AddOwnerScreenState();
}

class _AddOwnerScreenState extends State<AddOwnerScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final CollectionReference users = FirebaseFirestore.instance.collection('users');
  final CollectionReference owners = FirebaseFirestore.instance.collection('ev_owners');
  bool isLoading = false;

  Future<void> createOwner() async {
    if (emailController.text.isEmpty || passwordController.text.isEmpty) {
      Fluttertoast.showToast(msg: "Please fill all fields!");
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      String ownerId = userCredential.user!.uid;

      await users.doc(ownerId).set({
        'email': emailController.text.trim(),
        'role': 'owner',
      });

      await owners.doc(ownerId).set({
        'email': emailController.text.trim(),
        'approved': true,
      });

      emailController.clear();
      passwordController.clear();
      Fluttertoast.showToast(msg: "Owner account created successfully!");

    } catch (e) {
      Fluttertoast.showToast(msg: "Error: ${e.toString()}");
    }

    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF001F54),
      appBar: AppBar(
        title: Text("Add EV Owner", style: TextStyle(color: Colors.white)),
        backgroundColor: Color(0xFF0033AA),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: emailController,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Owner Email",
                labelStyle: TextStyle(color: Colors.white70),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            SizedBox(height: 15),
            TextField(
              controller: passwordController,
              obscureText: true,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Password",
                labelStyle: TextStyle(color: Colors.white70),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            SizedBox(height: 25),
            ElevatedButton(
              onPressed: isLoading ? null : createOwner,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF0033AA),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: isLoading
                  ? CircularProgressIndicator(color: Colors.white)
                  : Text("Create Owner Account", style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}
