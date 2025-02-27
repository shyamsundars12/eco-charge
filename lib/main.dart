import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'screens/signup_screen.dart';
import 'screens/home_screen.dart';
import 'screens/arrival_screen.dart';
import 'screens/map_screen.dart'; // ✅ Import Map Screen

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); // Initialize Firebase
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => AuthProvider()), // Provide AuthProvider globally
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'EcoCharge',
        theme: ThemeData(primarySwatch: Colors.blue),
        home: ArrivalScreen(), // Start at ArrivalScreen first
        routes: {
          '/map': (context) => MapScreen(), // ✅ Route to Map Screen
        },
      ),
    );
  }
}

class ArrivalScreen extends StatefulWidget {
  @override
  _ArrivalScreenState createState()  => _ArrivalScreenState();
}

class _ArrivalScreenState extends State<ArrivalScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(seconds: 3), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => AuthWrapper()), // ✅ Navigate to AuthWrapper
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green.shade700,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.electric_car,
              size: 100,
              color: Colors.white,
            ),
            const SizedBox(height: 20),
            Text(
              "EcoCharge",
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ✅ AuthWrapper: Checks if user is logged in or not
class AuthWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, child) {
        if (auth.user != null) {
          return MapScreen(); // ✅ Redirect to MapScreen after login
        } else {
          return SignupScreen(); // Otherwise, go to SignupScreen
        }
      },
    );
  }
}
