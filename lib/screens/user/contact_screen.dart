import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:ecocharge/screens/user/map_screen.dart';

class ContactScreen extends StatefulWidget {
  @override
  _ContactScreenState createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _queryController = TextEditingController();
  bool _isLoading = false;
  String? _userEmail;
                        
  @override
  void initState() {
    super.initState();
    _getUserEmail();
  }

  Future<void> _getUserEmail() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _userEmail = user.email;
      });
    }
  }

  Future<void> _sendEmail(String name, String phone, String query) async {
    try {
      // Create SMTP server configuration
      final smtpServer = gmail('ecochargefinder@gmail.com', 'fohy muai rkeh acdq');

      // Create the email message
      final message = Message()
        ..from = Address('ecochargefinder@gmail.com', 'EcoCharge Support')
        ..recipients.add('ecochargefinder@gmail.com') // Owner's email
        ..subject = 'New Query from $name'
        ..text = '''
Name: $name
Phone: $phone
Email: $_userEmail

Query:
$query
''';

      // Send the email
      final sendReport = await send(message, smtpServer);
      print('Message sent: ${sendReport.toString()}');

      // Send acknowledgment to user
      final userMessage = Message()
        ..from = Address('ecochargefinder@gmail.com', 'EcoCharge Support')
        ..recipients.add(_userEmail!)
        ..subject = 'Query Received - EcoCharge'
        ..text = '''
Dear $name,

Thank you for contacting EcoCharge. We have received your query and will get back to you shortly.

Your Query:
$query

Best regards,
EcoCharge Support Team
''';

      await send(userMessage, smtpServer);

      // Save query to Firestore
      await FirebaseFirestore.instance.collection('queries').add({
        'name': name,
        'phone': phone,
        'email': _userEmail,
        'query': query,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Query submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting query: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _submitQuery() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await _sendEmail(
        _nameController.text,
        _phoneController.text,
        _queryController.text,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Contact Us'),
        backgroundColor: Color(0xFF0033AA),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Have a question? We\'d love to hear from you.',
                style: TextStyle(fontSize: 18),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Your Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your name';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your phone number';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _queryController,
                decoration: InputDecoration(
                  labelText: 'Your Query',
                  border: OutlineInputBorder(),
                ),
                maxLines: 5,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your query';
                  }
                  return null;
                },
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _submitQuery,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF0033AA),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text('Submit Query'),
              ),
              SizedBox(height: 16),
              Text(
                'We will get back to you at: $_userEmail',
                style: TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _queryController.dispose();
    super.dispose();
  }
} 