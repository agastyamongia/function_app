import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/event.dart';
import '../services/event_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';

class EventRegistrationScreen extends StatefulWidget {
  final String eventId;

  const EventRegistrationScreen({
    super.key,
    required this.eventId,
  });

  @override
  State<EventRegistrationScreen> createState() => _EventRegistrationScreenState();
}

class _EventRegistrationScreenState extends State<EventRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();
  final _eventService = EventService();
  final _supabase = Supabase.instance.client;

  bool _isLoading = true;
  bool _isRegistering = false;
  bool _showNameField = false;
  Event? _event;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadEventDetails();
  }

  Future<void> _loadEventDetails() async {
    try {
      final event = await _eventService.getEvent(widget.eventId);
      if (mounted) {
        setState(() {
          _event = event;
          _isLoading = false;
          if (event == null) {
            _errorMessage = 'Event not found';
          } else if (!event.isPublished) {
            _errorMessage = 'This event is not yet published';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load event details';
        });
      }
    }
  }

  Future<void> _checkPhoneNumber() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isRegistering = true;
      _errorMessage = null;
    });

    try {
      // Format phone number to E.164 format
      String phoneNumber = _phoneController.text.trim();
      if (!phoneNumber.startsWith('+')) {
        phoneNumber = '+1$phoneNumber'; // Assuming US numbers
      }

      // Check if user exists in auth.users
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('phone', phoneNumber)
          .maybeSingle();

      if (response != null) {
        // User exists, proceed with registration
        await _registerExistingUser(response['id']);
      } else {
        // Show name field for new user registration
        setState(() {
          _showNameField = true;
          _isRegistering = false;
        });
      }
    } catch (e) {
      setState(() {
        _isRegistering = false;
        _errorMessage = 'Error checking phone number: $e';
      });
    }
  }

  Future<void> _registerExistingUser(String userId) async {
    try {
      await _eventService.registerForEvent(widget.eventId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Successfully registered for event!')),
        );
        // Show success screen or navigate back
      }
    } catch (e) {
      setState(() {
        _isRegistering = false;
        _errorMessage = 'Failed to register: $e';
      });
    }
  }

  Future<void> _registerNewUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isRegistering = true;
      _errorMessage = null;
    });

    try {
      String phoneNumber = _phoneController.text.trim();
      if (!phoneNumber.startsWith('+')) {
        phoneNumber = '+1$phoneNumber'; // Assuming US numbers
      }

      // Create new user profile
      final userResponse = await _supabase.from('profiles').insert({
        'phone': phoneNumber,
        'first_name': _nameController.text.trim(),
        'created_at': DateTime.now().toIso8601String(),
      }).select().single();

      // Register for event
      await _registerExistingUser(userResponse['id']);
    } catch (e) {
      setState(() {
        _isRegistering = false;
        _errorMessage = 'Failed to create profile: $e';
      });
    }
  }

  String? _validatePhoneNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a phone number';
    }
    // Basic phone number validation
    final phoneRegExp = RegExp(r'^\+?1?\d{10}$');
    if (!phoneRegExp.hasMatch(value.replaceAll(RegExp(r'[^\d]'), ''))) {
      return 'Please enter a valid phone number';
    }
    return null;
  }

  Widget _buildEventDetails() {
    if (_event == null) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _event!.title,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Hosted by ${_event!.rsoName}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _event!.description,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            _buildInfoRow(Icons.location_on, 'Location', _event!.location),
            const SizedBox(height: 8),
            _buildInfoRow(
              Icons.calendar_today,
              'Date',
              DateFormat('EEEE, MMMM d, y').format(_event!.startTime),
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              Icons.access_time,
              'Time',
              '${DateFormat('HH:mm').format(_event!.startTime)} - ${DateFormat('HH:mm').format(_event!.endTime)}',
            ),
            if (_event!.price != null) ...[
              const SizedBox(height: 8),
              _buildInfoRow(
                Icons.attach_money,
                'Price',
                '\$${_event!.price?.toStringAsFixed(2)}',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildRegistrationForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _phoneController,
            decoration: const InputDecoration(
              labelText: 'Phone Number',
              hintText: '(123) 456-7890',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.phone,
            validator: _validatePhoneNumber,
            enabled: !_showNameField,
          ),
          if (_showNameField) ...[
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your name';
                }
                return null;
              },
            ),
          ],
          const SizedBox(height: 24),
          if (_errorMessage != null) ...[
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
          ],
          ElevatedButton(
            onPressed: _isRegistering
                ? null
                : _showNameField
                    ? _registerNewUser
                    : _checkPhoneNumber,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _isRegistering
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(_showNameField ? 'Register' : 'Continue'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Registration'),
        actions: [
          // Show login button if user is not authenticated
          if (_supabase.auth.currentUser == null)
            TextButton.icon(
              onPressed: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              },
              icon: const Icon(Icons.login, color: Colors.white),
              label: const Text(
                'Login',
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null && _event == null
              ? Center(child: Text(_errorMessage!))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildEventDetails(),
                      const SizedBox(height: 24),
                      Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: _buildRegistrationForm(),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    super.dispose();
  }
} 