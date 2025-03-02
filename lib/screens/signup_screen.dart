import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'login_screen.dart';
import 'map_screen.dart';

class SignupScreen extends StatefulWidget {
  @override
  _SignupScreenState createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmpasswordController = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  void _signUp(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    String? error = await authProvider.signUpWithEmail(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );

    if (error == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => MapScreen()), // ✅ Navigate to MapScreen
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error, style: TextStyle(color: Colors.white)), backgroundColor: Colors.red),
      );
    }
    setState(() => _isLoading = false);
  }

  void _signInWithGoogle(BuildContext context) async {
    setState(() => _isLoading = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      String? error = await authProvider.signInWithGoogle();

      if (error == null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => MapScreen()), // ✅ Navigate to MapScreen
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error, style: TextStyle(color: Colors.white)), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Google Sign-In Failed: $e", style: TextStyle(color: Colors.white)), backgroundColor: Colors.red),
      );
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: 20),
                  SvgPicture.asset(
                    'assets/images/city_driver.svg',
                    height: 150,
                    width: 150,
                    placeholderBuilder: (context) => CircularProgressIndicator(),
                  ),
                  SizedBox(height: 30),
                  Text('Create Account', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  SizedBox(height: 20),
                  Text(
                    'Create an account to explore nearby EV charging stations!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  SizedBox(height: 20),

                  // Email Field
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: "Email",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      prefixIcon: Icon(Icons.email),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) return "Email cannot be empty";
                      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) return "Enter a valid email";
                      return null;
                    },
                  ),
                  SizedBox(height: 20),

                  // Password Field
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: "Password",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      prefixIcon: Icon(Icons.lock),
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) return "Password cannot be empty";
                      if (value.length < 6) return "Password must be at least 6 characters";
                      return null;
                    },
                  ),
                  SizedBox(height: 20),

                  // Confirm Password Field
                  TextFormField(
                    controller: _confirmpasswordController, // ✅ Fixed controller
                    decoration: InputDecoration(
                      labelText: "Confirm Password",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      prefixIcon: Icon(Icons.lock),
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) return "Confirm Password cannot be empty";
                      if (value != _passwordController.text) return "Passwords do not match"; // ✅ Password match validation
                      return null;
                    },
                  ),

                  SizedBox(height: 20),

                  // Sign Up Button
                  _isLoading
                      ? CircularProgressIndicator()
                      : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _signUp(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF0033AA),
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text("Sign up", style: TextStyle(fontSize: 18, color: Colors.white)),
                    ),
                  ),

                  SizedBox(height: 20),

                  // Navigate to Login
                  Text("Already have an account?", style: TextStyle(color: Colors.grey[600])),
                  TextButton(
                    onPressed: () => Navigator.push(
                        context, MaterialPageRoute(builder: (context) => LoginScreen())),
                    child: Text("Login"),
                  ),

                  SizedBox(height: 10),
                  Text("Or continue with"),
                  SizedBox(height: 10),

                  // Social Login Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: () => _signInWithGoogle(context),
                        icon: Icon(Icons.g_mobiledata, size: 32, color: Colors.red), // ✅ Fixed Google Sign-In
                      ),
                      IconButton(
                        onPressed: () {},
                        icon: Icon(Icons.facebook, size: 32, color: Colors.blue),
                      ),
                      IconButton(
                        onPressed: () {},
                        icon: Icon(Icons.apple, size: 32, color: Colors.black),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
