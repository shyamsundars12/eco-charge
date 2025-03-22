import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart  'as local_auth;
import '../../services/auth_service.dart';
import '../admin/admin_dashboard.dart';
import '../owner/owner_dashboard.dart';
import 'forgot_password.dart';
import 'signup_screen.dart';
import 'package:ecocharge/providers/auth_provider.dart';
import 'map_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService(); // Instance of AuthService
// Controller for email input
  final _emailController = TextEditingController();
  // Controller for password input
  final _passwordController = TextEditingController();
  // To show spinner during login
  bool _isLoading = false;

  // Login function to handle user authentication
  void _login() async {
    setState(() {
      _isLoading = true; // Show spinner

    });

    // Call login method from AuthService with user inputs
    String? result = await _authService.login(
      email: _emailController.text,
      password: _passwordController.text,
    );

    setState(() {
      _isLoading = false; // Hide spinner
    });

    // Navigate based on role or show error message
    if (result == 'Admin') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>  AdminDashboard(),
        ),
      );
    } else if (result == 'User') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>  MapScreen(),
        ),
      );
    }
    else if(result=='owner'){
      Navigator.pushReplacement(
          context,
          MaterialPageRoute(
          builder:(_)=> OwnerDashboard()
    ),
      );
    }

    else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Login Failed: $result'), // Show error message
      ));
    }
  }

  bool isPasswordHidden = true;

  Future<void> _navigateBasedOnRole(String userId, BuildContext context) async {
    try {
      DocumentSnapshot userDoc =
      await FirebaseFirestore.instance.collection('users').doc(userId).get();

      if (userDoc.exists) {
        String role = userDoc['role'] ?? '';

        if (role.isEmpty) throw Exception("User role not found in Firestore!");

        Widget destination;
        if (role == 'user') {
          destination =  MapScreen();
        } else if (role == 'admin') {
          destination =  OwnerDashboard();
        } else if (role == 'owner') {
          destination =  OwnerDashboard();
        } else {
          throw Exception("Invalid role found in Firestore: $role");
        }

        if (!mounted) return;
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (context) => destination));
      } else {
        throw Exception("User document not found in Firestore!");
      }
    } catch (e) {
      _showError("Error retrieving user role: ${e.toString()}");
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: SingleChildScrollView(
            child: Form(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  SvgPicture.asset(
                    'assets/images/login_img.svg',
                    height: 150,
                    width: 150,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Login Here",
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Welcome back! You've been missed!",
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 20),

                  // Email Field
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: "Email",
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      prefixIcon: const Icon(Icons.email),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return "Email cannot be empty";
                      }
                      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                        return "Enter a valid email";
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Password Field
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: "Password",
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      prefixIcon: const Icon(Icons.lock),
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return "Password cannot be empty";
                      }
                      if (value.length < 6) {
                        return "Password must be at least 6 characters";
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 20),

                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>  ForgotPasswordPage()),
                      ),
                      child: const Text("Forgot your password?",
                          style: TextStyle(color: Colors.blue)),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Login Button
                  _isLoading
                      ? const CircularProgressIndicator()
                      : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _login(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0033AA),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text("Sign in",
                          style: TextStyle(
                              fontSize: 18, color: Colors.white)),
                    ),
                  ),

                  const SizedBox(height: 40),

                  const Text("Don't have an account?"),
                  TextButton(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>  SignupScreen())),
                    child: const Text("Sign up here"),
                  ),
                  SizedBox(height: 10),
                 /* Text("Or continue with"),
                  SizedBox(height: 10),*/

                 /* Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: () => _signInWithGoogle(context),
                        icon: Icon(Icons.g_mobiledata, size: 32, color: Colors.red), // ✅ Uses FontAwesome Google icon
                      ),
                      IconButton(
                        onPressed: () {},
                        icon: Icon(Icons.facebook, size: 40, color: Colors.blue),
                      ),
                      IconButton(
                        onPressed: () {},
                        icon: Icon(Icons.apple, size: 40, color: Colors.black),
                      ),
                    ],
                  ),*/
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _signInWithGoogle(BuildContext context) async {
    setState(() => _isLoading = true);

    final authProvider = Provider.of<local_auth.AuthProvider>(context, listen: false);
    String? error = await authProvider.signInWithGoogle();

    if (error == null) {
      if (FirebaseAuth.instance.currentUser != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => MapScreen()), // ✅ Navigate to MapScreen
        );
      }
    } else if (error != "Google Sign-In was canceled.") {
      // Show error message only if it's a real error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error, style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.red,
        ),
      );
    }

    // Only reset loading state if there's an error
    if (error != null) {
      setState(() => _isLoading = false);
    }
  }

}
