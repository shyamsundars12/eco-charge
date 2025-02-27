import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'screens/signup_screen.dart';
import 'screens/home_screen.dart';
import 'screens/arrival_screen.dart';

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
        title: 'Flutter Auth',
        theme: ThemeData(primarySwatch: Colors.blue),
        home: ArrivalScreen(), // Start at ArrivalScreen first
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
        MaterialPageRoute(builder: (context) => AuthWrapper()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:Colors.green,
      body: Center(
        child: Text(
          "Eco Charge",
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
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
          return HomeScreen(); // If user is logged in, go to HomeScreen
        } else {
          return SignupScreen(); // Otherwise, go to SignupScreen
        }
      },
    );
  }
}