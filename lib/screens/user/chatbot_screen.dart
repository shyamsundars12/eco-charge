import 'package:flutter/material.dart';

class ChatbotScreen extends StatefulWidget {
  @override
  _ChatbotScreenState createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;
  String? _currentContext;
  Map<String, dynamic> _userPreferences = {};

  // Enhanced responses with context and follow-up questions
  final Map<String, Map<String, dynamic>> _responses = {
    'greeting': {
      'responses': [
        'Hello! I\'m your EcoCharge assistant. How can I help you today?',
        'Hi there! Welcome to EcoCharge. What would you like to know?',
        'Welcome! I can help you with booking, pricing, and finding stations. What would you like to know?'
      ],
      'followUp': 'Is there anything specific you\'d like to know about our services?'
    },
    'booking': {
      'responses': [
        'To book a charging slot:\n1. Select a station from the map\n2. Choose your preferred date and time\n3. Enter your vehicle details\n4. Complete the payment\n5. You\'ll receive a confirmation email',
        'Here\'s how to book:\n- Find a station on the map\n- Select your preferred time slot\n- Fill in your vehicle details\n- Make the payment\n- Get your booking confirmation'
      ],
      'followUp': 'Would you like to know about our pricing or available time slots?',
      'context': {
        'vehicle': 'What type of vehicle do you have?',
        'time': 'What time would you prefer to charge?',
        'duration': 'How long do you need to charge?'
      }
    },
    'pricing': {
      'responses': [
        'Our charging rates are:\n- Fast Charging: ₹15 per kWh\n- Standard Charging: ₹10 per kWh\n- Additional fees may apply for extended stays',
        'Current pricing:\n• Fast Charging: ₹15/kWh\n• Standard: ₹10/kWh\n• Extended stay fees apply'
      ],
      'followUp': 'Would you like to know about our different charging options or payment methods?',
      'context': {
        'fast': 'Fast charging is ideal for quick top-ups. Would you like to know more about fast charging?',
        'standard': 'Standard charging is more economical. Would you like to know more about standard charging?'
      }
    },
    'location': {
      'responses': [
        'You can find charging stations by:\n1. Opening the map view\n2. Looking for the charging station icons\n3. Clicking on a station to see details',
        'To locate stations:\n- Use the map view\n- Look for station icons\n- Tap to view details'
      ],
      'followUp': 'Would you like to know about station features or availability?',
      'context': {
        'features': 'Our stations offer:\n- Fast and standard charging\n- 24/7 availability\n- Security cameras\n- Rest area\nWould you like to know more about any of these features?',
        'availability': 'Most stations are open 24/7. Would you like to check real-time availability?'
      }
    },
    'time': {
      'responses': [
        'Charging time varies by vehicle:\n- Fast Charging: 30-60 minutes\n- Standard Charging: 2-4 hours\n- Exact time depends on your battery level',
        'Typical charging times:\n• Fast: 30-60 mins\n• Standard: 2-4 hours\n• Varies by battery level'
      ],
      'followUp': 'Would you like to know about factors affecting charging time or how to optimize it?',
      'context': {
        'factors': 'Charging time depends on:\n- Battery capacity\n- Current charge level\n- Charging speed\n- Temperature\nWould you like to know more about any of these factors?',
        'optimize': 'To optimize charging time:\n1. Pre-condition your battery\n2. Choose fast charging when available\n3. Charge during off-peak hours\nWould you like more tips?'
      }
    },
    'payment': {
      'responses': [
        'We accept multiple payment methods:\n- Credit/Debit cards\n- UPI\n- Net banking\n- Cash (at select locations)',
        'Payment options:\n• Cards\n• UPI\n• Net Banking\n• Cash (select locations)'
      ],
      'followUp': 'Would you like to know about our payment security or refund policy?',
      'context': {
        'security': 'We use industry-standard encryption for all payments. Would you like to know more about our security measures?',
        'refund': 'Refunds are processed within 5-7 business days. Would you like to know more about our refund process?'
      }
    },
    'default': {
      'responses': [
        'I\'m not sure about that. Here are some topics I can help with:\n\n1. Booking a charging slot\n2. Finding charging stations\n3. Understanding pricing\n4. Payment methods\n5. Charging time\n\nPlease ask about any of these topics!',
        'I don\'t have information about that. Would you like to know about:\n• Booking process\n• Station locations\n• Pricing\n• Payment options\n• Charging duration'
      ],
      'followUp': 'Is there anything else you\'d like to know?'
    }
  };

  // Enhanced keywords with context triggers
  final Map<String, Map<String, List<String>>> _keywords = {
    'greeting': {
      'keywords': ['hi', 'hello', 'hey', 'good morning', 'good afternoon', 'good evening'],
      'context_triggers': []
    },
    'booking': {
      'keywords': ['book', 'booking', 'reserve', 'slot', 'schedule', 'appointment'],
      'context_triggers': ['vehicle', 'time', 'duration']
    },
    'pricing': {
      'keywords': ['price', 'cost', 'rate', 'charges', 'fee', 'pricing'],
      'context_triggers': ['fast', 'standard']
    },
    'location': {
      'keywords': ['where', 'location', 'find', 'station', 'place', 'address'],
      'context_triggers': ['features', 'availability']
    },
    'time': {
      'keywords': ['time', 'duration', 'how long', 'when', 'schedule', 'timing'],
      'context_triggers': ['factors', 'optimize']
    },
    'payment': {
      'keywords': ['pay', 'payment', 'money', 'card', 'upi', 'cash'],
      'context_triggers': ['security', 'refund']
    }
  };

  String _getResponse(String userMessage) {
    userMessage = userMessage.toLowerCase();
    
    // Check for context-specific responses first
    if (_currentContext != null && _responses[_currentContext!]?['context'] != null) {
      final contextResponses = _responses[_currentContext!]!['context'] as Map<String, String>;
      for (var key in contextResponses.keys) {
        if (userMessage.contains(key)) {
          return contextResponses[key]!;
        }
      }
    }

    // Check for greetings first
    if (_keywords['greeting']!['keywords']!.any((keyword) => userMessage.contains(keyword))) {
      _currentContext = null;
      return _responses['greeting']!['responses']![DateTime.now().millisecondsSinceEpoch % 3];
    }

    // Check other categories
    for (var category in _keywords.keys) {
      if (_keywords[category]!['keywords']!.any((keyword) => userMessage.contains(keyword))) {
        _currentContext = category;
        final response = _responses[category]!['responses']![DateTime.now().millisecondsSinceEpoch % 2];
        final followUp = _responses[category]!['followUp'] as String;
        return '$response\n\n$followUp';
      }
    }

    // Default response if no match found
    _currentContext = null;
    return _responses['default']!['responses']![DateTime.now().millisecondsSinceEpoch % 2];
  }

  Future<void> _sendMessage(String text) async {
    if (text.isEmpty) return;

    setState(() {
      _messages.add({
        "message": text,
        "isUserMessage": true,
      });
      _isLoading = true;
    });

    _controller.clear();

    // Simulate network delay
    await Future.delayed(Duration(milliseconds: 500));

    setState(() {
      _messages.add({
        "message": _getResponse(text),
        "isUserMessage": false,
      });
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('EcoCharge Assistant'),
        backgroundColor: Color(0xFF0033AA),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return _buildMessage(message);
              },
            ),
          ),
          if (_isLoading)
            Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(),
            ),
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Ask me anything about EcoCharge...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    onSubmitted: _sendMessage,
                  ),
                ),
                SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.send),
                  color: Color(0xFF0033AA),
                  onPressed: () => _sendMessage(_controller.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(Map<String, dynamic> message) {
    return Align(
      alignment: message['isUserMessage']
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 4),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: message['isUserMessage']
              ? Color(0xFF0033AA)
              : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          message['message'],
          style: TextStyle(
            color: message['isUserMessage'] ? Colors.white : Colors.black,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
} 