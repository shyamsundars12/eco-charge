import 'package:flutter/material.dart';
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

    String? error = await authProvider.signInWithGoogle(); // ❌ Removed context argument

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
                  Image.asset('assets/images/welcome_image.jpg', height: 150),
                  SizedBox(height: 20),
                  Text('Create Account', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text(
                    'Create an account to explore nearby EV charging stations!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
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

                  SizedBox(height: 20),

                  _isLoading
                      ? CircularProgressIndicator()
                      : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _signUp(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text("Sign up", style: TextStyle(fontSize: 18)),
                    ),
                  ),

                  SizedBox(height: 10),

                  Text("Already have an account?", style: TextStyle(color: Colors.grey[600])),
                  TextButton(
                    onPressed: () => Navigator.push(
                        context, MaterialPageRoute(builder: (context) => LoginScreen())),
                    child: Text("Login"),
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
