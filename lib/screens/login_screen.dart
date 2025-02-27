import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'signup_screen.dart';
import 'map_screen.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>(); // ✅ Added Form Key
  bool _isLoading = false;

  void _login(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    String? error = await authProvider.signInWithEmail(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );

    if (error == null) {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (context) => MapScreen())); // ✅ Navigate to MapScreen
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

    String? error = await authProvider.signInWithGoogle(); // ❌ Removed context argument

    if (error == null) {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (context) => MapScreen())); // ✅ Navigate to MapScreen
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error, style: TextStyle(color: Colors.white)), backgroundColor: Colors.red),
      );
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: SingleChildScrollView(
            child: Form(
              key: _formKey, // ✅ Added Form widget
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Login Here", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text("Welcome back! You've been missed!", style: TextStyle(color: Colors.grey)),
                  SizedBox(height: 20),

                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: "Email",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) return "Email cannot be empty";
                      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) return "Enter a valid email";
                      return null;
                    },
                  ),
                  SizedBox(height: 10),

                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: "Password",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) return "Password cannot be empty";
                      if (value.length < 6) return "Password must be at least 6 characters";
                      return null;
                    },
                  ),

                  SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {},
                      child: Text("Forgot your password?", style: TextStyle(color: Colors.blue)),
                    ),
                  ),
                  SizedBox(height: 20),

                  _isLoading
                      ? CircularProgressIndicator()
                      : ElevatedButton(
                    onPressed: () => _login(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 40),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text("Sign in", style: TextStyle(fontSize: 16)),
                  ),

                  SizedBox(height: 20),

                  Text("Don't have an account?"),
                  TextButton(
                    onPressed: () => Navigator.push(
                        context, MaterialPageRoute(builder: (context) => SignupScreen())),
                    child: Text("Sign up here"),
                  ),

                  SizedBox(height: 10),
                  Text("Or continue with"),
                  SizedBox(height: 10),

                  Row(
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
