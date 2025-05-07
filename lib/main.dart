import 'package:ecocharge/screens/admin/manage_station_screen.dart';
import 'package:ecocharge/screens/user/login_screen.dart';
import 'package:ecocharge/screens/user/map_screen.dart';
import 'package:ecocharge/services/notification_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:ecocharge/screens/user/map_screen.dart';

import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/booking_provider.dart';
import 'providers/station_provider.dart';
import 'screens/admin/admin_dashboard.dart';
import 'screens/owner/owner_dashboard.dart';
import 'screens/admin/add_owner_screen.dart';
import 'screens/admin/manage_bookings_screen.dart';
import 'screens/admin/owner_wise_reports_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await NotificationService().initNotifications();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => AuthProvider()),
        ChangeNotifierProvider(create: (context) => BookingProvider()),
        ChangeNotifierProvider(create: (context) => StationProvider()),
      ],
      child: const EcoChargeApp(),
    ),
  );
}

class EcoChargeApp extends StatelessWidget {
  const EcoChargeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'EcoCharge',
      theme: ThemeData(primarySwatch: Colors.green),
      home: const ArrivalScreen(),
      initialRoute: '/',
      routes: {
        '/admin_dashboard': (context) => AdminDashboard(),
        '/owner_dashboard': (context) => OwnerDashboard(),
        '/manage_owners': (context) => AddOwnerScreen(),
        '/manage_stations': (context) => ManageStationScreen(),
        '/manage_bookings': (context) => ManageBookingsScreen(),
        '/owner_wise_reports': (context) => OwnerWiseReportsScreen(),
        '/login': (context) => LoginScreen(),
        '/map': (context) => MapScreen(),
      },
    );
  }
}

class ArrivalScreen extends StatefulWidget {
  const ArrivalScreen({super.key});

  @override
  _ArrivalScreenState createState() => _ArrivalScreenState();
}

class _ArrivalScreenState extends State<ArrivalScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (context) => const AuthWrapper()));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0033AA),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              'assets/images/hybrid_car.svg',
              height: 150,
              width: 150,
            ),
            const SizedBox(height: 10),
            const Text(
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
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        if (authProvider.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (authProvider.userModel == null) {
          return LoginScreen();
        }

        final String? role = authProvider.userModel!.role;
        if (role == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        switch (role) {
          case 'admin':
            return AdminDashboard();
          case 'owner':
            return OwnerDashboard();
          default:
            return MapScreen();
        }
      },
    );
  }
}