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
  final String pointId;

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
    required this.pointId,
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
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse response) {
      _handlePaymentSuccess(response);
    });
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse response) {
      _handlePaymentError(response);
    });
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, (ExternalWalletResponse response) {
      _handleExternalWallet(response);
    });
    _fetchStationName();
    _startPaymentTimeout();
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
        ..html = '''
<!DOCTYPE html>
<html>
<head>
    <style>
        body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
        .container { max-width: 600px; margin: 0 auto; padding: 20px; }
        .header { background-color: #0033AA; color: white; padding: 20px; text-align: center; }
        .content { padding: 20px; background-color: #f9f9f9; }
        .details { background-color: white; padding: 20px; margin: 20px 0; border-radius: 5px; }
        .footer { text-align: center; padding: 20px; color: #666; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h2>Booking Confirmation</h2>
        </div>
        <div class="content">
            <p>Dear Valued Customer,</p>
            <p>Your booking has been confirmed successfully!</p>
            
            <div class="details">
                <h3>Booking Details:</h3>
                <p><strong>Station:</strong> $_stationName</p>
                <p><strong>Vehicle Number:</strong> ${widget.vehicleNumber}</p>
                <p><strong>Vehicle Model:</strong> ${widget.vehicleModel}</p>
                <p><strong>Charging Capacity:</strong> ${widget.chargingCapacity} kWh</p>
                <p><strong>Date:</strong> ${widget.date}</p>
                <p><strong>Time:</strong> ${widget.slotTime}</p>
                <p><strong>Total Amount:</strong> ₹${widget.amount.toStringAsFixed(2)}</p>
                <p><strong>Advance Paid:</strong> ₹${(widget.amount * 0.5).toStringAsFixed(2)}</p>
                <p><strong>Remaining Amount:</strong> ₹${(widget.amount * 0.5).toStringAsFixed(2)}</p>
            </div>
            
            <p>Thank you for choosing EcoCharge. We look forward to serving you!</p>
        </div>
        <div class="footer">
            <p>Best regards,<br>EcoCharge Team</p>
        </div>
    </div>
</body>
</html>
''';

      // Send the email
      final sendReport = await send(message, smtpServer);
      print('Booking confirmation email sent successfully');
      
      // Show success message to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Booking confirmation email sent successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error sending booking confirmation email: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending confirmation email: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handlePaymentSuccess(PaymentSuccessResponse response) async {
    try {
      setState(() => _isLoading = true);

      // Get current user
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      // Create booking document
      DocumentReference bookingRef = await _firestore.collection('bookings').add({
        'user_id': user.uid,
        'station_id': widget.stationId,
        'slot_id': widget.slotId,
        'point_id': widget.pointId,
        'date': widget.date,
        'time': widget.slotTime,
        'vehicle_number': widget.vehicleNumber,
        'vehicle_model': widget.vehicleModel,
        'charging_capacity': double.parse(widget.chargingCapacity),
        'total_amount': widget.amount,
        'advance_paid': widget.amount * 0.5,
        'remaining_amount': widget.amount * 0.5,
        'status': 'booked',
        'payment_status': 'partial',
        'payment_id': response.paymentId,
        'payment_timestamp': FieldValue.serverTimestamp(),
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });

      // Get the slot document
      DocumentSnapshot slotDoc = await _firestore
          .collection('charging_slots')
          .doc(widget.stationId)
          .collection('slots')
          .doc(widget.slotId)
          .get();

      if (!slotDoc.exists) {
        throw Exception('Slot not found');
      }

      Map<String, dynamic> slotData = slotDoc.data() as Map<String, dynamic>;
      List<dynamic> chargingPoints = List.from(slotData['charging_points'] ?? []);

      // Find and update the charging point status
      bool pointFound = false;
      for (int i = 0; i < chargingPoints.length; i++) {
        if (chargingPoints[i]['id'].toString() == widget.pointId) {
          chargingPoints[i]['status'] = 'booked';
          chargingPoints[i]['booked_by'] = user.uid;
          chargingPoints[i]['pending_by'] = null;
          chargingPoints[i]['updated_at'] = DateTime.now().toIso8601String();
          pointFound = true;
          break;
        }
      }

      if (!pointFound) {
        throw Exception('Charging point not found');
      }

      // Update the slot with the modified charging points
      await _firestore
          .collection('charging_slots')
          .doc(widget.stationId)
          .collection('slots')
          .doc(widget.slotId)
          .update({
        'charging_points': chargingPoints,
        'updated_at': FieldValue.serverTimestamp(),
      });

      // Get user email for confirmation
      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        String userEmail = userDoc.get('email');
        String stationName = userDoc.get('name') ?? 'Unknown Station';
        
        // Send booking confirmation email
        await _firestore.collection('mail').add({
          'to': userEmail,
          'message': {
            'subject': 'Booking Confirmation - EcoCharge',
            'text': '''
            Your booking has been confirmed!
            
            Booking Details:
            Station: $stationName
            Date: ${widget.date}
            Time: ${widget.slotTime}
            Charging Point: ${widget.pointId}
            Vehicle Number: ${widget.vehicleNumber}
            Vehicle Model: ${widget.vehicleModel}
            Charging Capacity: ${widget.chargingCapacity} kWh
            Total Amount: ₹${widget.amount.toStringAsFixed(2)}
            Advance Paid: ₹${(widget.amount * 0.5).toStringAsFixed(2)}
            Remaining Amount: ₹${(widget.amount * 0.5).toStringAsFixed(2)}
            Payment ID: ${response.paymentId}
            Booking ID: ${bookingRef.id}
            
            Note: Please pay the remaining amount at the station.
            
            Thank you for choosing EcoCharge!
            ''',
          },
        });
      }

      // Send booking confirmation email
      await _sendBookingConfirmationEmail();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment successful! Booking confirmed.'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate to MyBookingsScreen and clear the navigation stack
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => const MyBookingsScreen(),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      print('Error in payment success handler: $e');
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

  void _handlePaymentError(PaymentFailureResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Payment failed: ${response.message}'),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('External wallet selected: ${response.walletName}'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  Future<void> _startPaymentTimeout() async {
    // Create a temporary booking with pending status
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      DocumentReference bookingRef = await _firestore.collection('bookings').add({
        'user_id': user.uid,
        'station_id': widget.stationId,
        'slot_id': widget.slotId,
        'point_id': widget.pointId,
        'date': widget.date,
        'time': widget.slotTime,
        'vehicle_number': widget.vehicleNumber,
        'vehicle_model': widget.vehicleModel,
        'charging_capacity': double.parse(widget.chargingCapacity),
        'total_amount': widget.amount,
        'advance_paid': 0.0,
        'remaining_amount': widget.amount,
        'status': 'pending',
        'payment_status': 'pending',
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });

      // Update the charging point status to pending
      DocumentSnapshot slotDoc = await _firestore
          .collection('charging_slots')
          .doc(widget.stationId)
          .collection('slots')
          .doc(widget.slotId)
          .get();

      if (!slotDoc.exists) {
        throw Exception('Slot not found');
      }

      Map<String, dynamic> slotData = slotDoc.data() as Map<String, dynamic>;
      List<dynamic> chargingPoints = List.from(slotData['charging_points'] ?? []);

      bool pointFound = false;
      for (int i = 0; i < chargingPoints.length; i++) {
        if (chargingPoints[i]['id'].toString() == widget.pointId) {
          chargingPoints[i]['status'] = 'pending';
          chargingPoints[i]['pending_by'] = user.uid;
          chargingPoints[i]['updated_at'] = DateTime.now().toIso8601String();
          pointFound = true;
          break;
        }
      }

      if (!pointFound) {
        throw Exception('Charging point not found');
      }

      await _firestore
          .collection('charging_slots')
          .doc(widget.stationId)
          .collection('slots')
          .doc(widget.slotId)
          .update({
        'charging_points': chargingPoints,
        'updated_at': FieldValue.serverTimestamp(),
      });

      // Set a timeout to release the slot after 5 minutes
      Future.delayed(const Duration(minutes: 5), () async {
        // Check if the booking is still pending
        DocumentSnapshot bookingSnapshot = await bookingRef.get();
        if (bookingSnapshot.exists && bookingSnapshot['status'] == 'pending') {
          // Release the slot
          await _releaseSlot(bookingRef.id);
        }
      });
    } catch (e) {
      print('Error creating temporary booking: $e');
    }
  }

  Future<void> _releaseSlot(String bookingId) async {
    try {
      // Get booking details
      DocumentSnapshot bookingDoc = await _firestore
          .collection('bookings')
          .doc(bookingId)
          .get();

      if (!bookingDoc.exists) return;

      Map<String, dynamic> booking = bookingDoc.data() as Map<String, dynamic>;

      // Get slot document
      DocumentSnapshot slotDoc = await _firestore
          .collection('charging_slots')
          .doc(booking['station_id'])
          .collection('slots')
          .doc(booking['slot_id'])
          .get();

      if (!slotDoc.exists) return;

      Map<String, dynamic> slotData = slotDoc.data() as Map<String, dynamic>;
      List<dynamic> chargingPoints = List.from(slotData['charging_points'] ?? []);

      // Find and update the charging point status
      for (int i = 0; i < chargingPoints.length; i++) {
        if (chargingPoints[i]['id'].toString() == booking['point_id']) {
          chargingPoints[i]['status'] = 'available';
          chargingPoints[i]['pending_by'] = null;
          chargingPoints[i]['updated_at'] = DateTime.now().toIso8601String();
          break;
        }
      }

      // Update the slot
      await _firestore
          .collection('charging_slots')
          .doc(booking['station_id'])
          .collection('slots')
          .doc(booking['slot_id'])
          .update({
        'charging_points': chargingPoints,
        'updated_at': FieldValue.serverTimestamp(),
      });

      // Update booking status
      await _firestore.collection('bookings').doc(bookingId).update({
        'status': 'cancelled',
        'updated_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error releasing slot: $e');
    }
  }

  void _startPayment() {
    if (_isLoading) return; // Prevent multiple touches

    setState(() => _isLoading = true);
    
    var options = {
      'key': 'rzp_test_BN58I09Ntf1QYq',
      'amount': (widget.amount * 50).toInt(), // 50% of total amount
      'name': 'EcoCharge',
      'description': 'Charging Station Booking - Advance Payment',
      'prefill': {
        'contact': '9999999999',
        'email': _auth.currentUser?.email ?? 'user@example.com',
      },
      'theme': {'color': '#0033AA'},
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      setState(() => _isLoading = false);
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _isLoading ? null : () => Navigator.pop(context),
        ),
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
                    _buildSummaryRow('Advance Payment (50%)', '₹${(widget.amount * 0.5).toStringAsFixed(2)}', isAmount: true),
                    _buildSummaryRow('Remaining Amount (Pay at Station)', '₹${(widget.amount * 0.5).toStringAsFixed(2)}', isAmount: true),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _startPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0033AA),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('Pay Advance (50%)', style: TextStyle(fontSize: 18)),
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
