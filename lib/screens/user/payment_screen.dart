import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'my_bookings_screen.dart';
import '../../services/notification_service.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

class PaymentScreen extends StatefulWidget {
  final String stationId;
  final String vehicleNumber;
  final String vehicleModel;
  final String chargingCapacity;
  final String slotTime;
  final double amount;
  final String bookingId;
  final String slotId;
  final String date;

  const PaymentScreen({
    Key? key,
    required this.stationId,
    required this.vehicleNumber,
    required this.vehicleModel,
    required this.chargingCapacity,
    required this.slotTime,
    required this.amount,
    required this.bookingId,
    required this.slotId,
    required this.date,
  }) : super(key: key);

  @override
  _PaymentScreenState createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  late Razorpay _razorpay;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();
  bool _isLoading = false;
  String? _stationName;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    _fetchStationName();
  }

  Future<void> _fetchStationName() async {
    try {
      DocumentSnapshot stationSnapshot =
      await _firestore.collection('ev_stations').doc(widget.stationId).get();
      if (stationSnapshot.exists) {
        setState(() {
          _stationName = stationSnapshot['name'];
        });
      }
    } catch (e) {
      print('Error fetching station name: $e');
    }
  }

  Future<void> _sendBookingConfirmationEmail() async {
    try {
      // Get current user's email
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.email == null) {
        print('No user email found');
        return;
      }

      // Create SMTP server configuration
      final smtpServer = gmail('ecochargefinder@gmail.com', 'fohy muai rkeh acdq');

      // Create the email message
      final message = Message()
        ..from = Address('ecochargefinder@gmail.com', 'EcoCharge')
        ..recipients.add(user.email!) // Use user's email from Firebase Auth
        ..subject = 'Booking Confirmation - EcoCharge'
        ..text = '''
Dear Valued Customer,

Your booking has been confirmed successfully!

Booking Details:
Station: $_stationName
Vehicle Number: ${widget.vehicleNumber}
Vehicle Model: ${widget.vehicleModel}
Charging Capacity: ${widget.chargingCapacity}
Date: ${widget.date}
Time: ${widget.slotTime}
Amount: ₹${widget.amount.toStringAsFixed(2)}

Thank you for choosing EcoCharge. We look forward to serving you!

Best regards,
EcoCharge Team
''';

      // Send the email
      final sendReport = await send(message, smtpServer);
      print('Booking confirmation email sent: ${sendReport.toString()}');
    } catch (e) {
      print('Error sending booking confirmation email: $e');
    }
  }

  Future<void> _handlePaymentSuccess(PaymentSuccessResponse response) async {
    try {
      setState(() => _isLoading = true);

      // Create booking document
      final bookingRef = _firestore.collection('bookings').doc();
      
      // Get current timestamp
      final now = DateTime.now();
      final timestamp = Timestamp.fromDate(now);

      // Create booking data
      final bookingData = {
        'amount': widget.amount,
        'cancelledAt': null, // Will be set when cancelled
        'chargingCapacity': widget.chargingCapacity,
        'date': widget.date,
        'paymentId': response.paymentId,
        'paymentStatus': 'success',
        'paymentTimestamp': timestamp,
        'slotTime': widget.slotTime,
        'stationId': widget.stationId,
        'status': 'booked',
        'timestamp': timestamp,
        'userId': _auth.currentUser?.uid,
        'vehicleModel': widget.vehicleModel,
        'vehicleNumber': widget.vehicleNumber,
      };

      // Save booking details
      await bookingRef.set(bookingData);

      // Update slot status
      await _firestore
          .collection('charging_slots')
          .doc(widget.stationId)
          .collection('slots')
          .doc('${widget.date}_${widget.slotTime}')
          .update({
        'status': 'booked',
        'booked_by': _auth.currentUser?.uid,
        'updated_at': FieldValue.serverTimestamp(),
      });

      // Send booking confirmation email
      await _sendBookingConfirmationEmail();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment successful! Booking confirmed.'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const MyBookingsScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing payment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) async {
    try {
      // Use a transaction to ensure atomic updates
      await _firestore.runTransaction((transaction) async {
        // Get the booking document
        final bookingDoc = await transaction.get(
          _firestore
              .collection('users')
              .doc(_auth.currentUser?.uid)
              .collection('bookings')
              .doc(widget.bookingId)
        );

        if (!bookingDoc.exists) {
          throw Exception('Booking not found');
        }

        // Get the slot document
        final slotDoc = await transaction.get(
          _firestore
              .collection('charging_slots')
              .doc(widget.stationId)
              .collection('slots')
              .doc(widget.slotId)
        );

        if (!slotDoc.exists) {
          throw Exception('Slot not found');
        }

        // Update booking status to failed
        transaction.update(bookingDoc.reference, {
          'status': 'failed',
          'payment_status': 'failed',
          'payment_error': response.message,
          'payment_timestamp': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        });

        // Release the slot back to available
        transaction.update(slotDoc.reference, {
          'status': 'available',
          'pending_by': null,
          'updated_at': FieldValue.serverTimestamp(),
        });
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment failed: ${response.message}'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      print('Error handling payment failure: $e');
    }
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('External wallet selected: ${response.walletName}')),
    );
  }

  void _startPayment() {
    var options = {
      'key': 'rzp_test_BN58I09Ntf1QYq',
      'amount': (widget.amount * 100).toInt(),
      'name': 'EcoCharge',
      'description': 'Charging Station Booking',
      'prefill': {'contact': '9999999999', 'email': 'user@example.com', 'name': 'User Name'},
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment'),
        backgroundColor: const Color(0xFF0033AA),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Booking Summary', style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 16),
                    _buildSummaryRow('Station Name', _stationName ?? 'Loading...'),
                    _buildSummaryRow('Vehicle Number', widget.vehicleNumber),
                    _buildSummaryRow('Vehicle Model', widget.vehicleModel),
                    _buildSummaryRow('Charging Capacity', '${widget.chargingCapacity} kWh'),
                    _buildSummaryRow('Slot Time', widget.slotTime),
                    const Divider(height: 32),
                    _buildSummaryRow('Total Amount', '₹${widget.amount.toStringAsFixed(2)}', isAmount: true),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _startPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0033AA),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Pay Now', style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isAmount = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16, color: Colors.grey)),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: isAmount ? FontWeight.bold : FontWeight.normal, color: isAmount ? const Color(0xFF0033AA) : Colors.black)),
        ],
      ),
    );
  }
}
