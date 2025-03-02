import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart' show SvgPicture;
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'screens/signup_screen.dart';
import 'screens/map_screen.dart';
import 'screens/vehicle_details_screen.dart';
// import 'screens/payment_screen.dart';
import 'screens/my_bookings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => AuthProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'EcoCharge',
        theme: ThemeData(primarySwatch: Colors.blue),
        initialRoute: '/',
        routes: {
          '/': (context) => ArrivalScreen(),
          '/auth': (context) => AuthWrapper(),
          '/map': (context) => MapScreen(),
          '/vehicleDetails': (context) => VehicleDetailsScreen(stationId: "123"),
          // '/payment': (context) => PaymentScreen(vehicleNumber: "", vehicleModel: "", chargingSlot: ""),
          '/myBookings': (context) => MyBookingsScreen(),
        },
      ),
    );
  }
}

class ArrivalScreen extends StatefulWidget {
  @override
  _ArrivalScreenState createState() => _ArrivalScreenState();
}

class _ArrivalScreenState extends State<ArrivalScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(seconds: 3), () {
      Navigator.pushReplacementNamed(context, '/auth');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0033AA),


      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              'assets/images/hybrid_car.svg',
              height: 150,
              width: 150,
            ),
            SizedBox(height: 10),
            Text(
              "EcoCharge",
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, child) {
        return auth.user != null ? MapScreen() : SignupScreen();
      },
    );
  }
}
