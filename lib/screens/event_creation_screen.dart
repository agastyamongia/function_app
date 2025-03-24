import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/event_service.dart';
import '../services/rso_service.dart';

class EventCreationScreen extends StatefulWidget {
  final Function? onEventCreated;
  
  const EventCreationScreen({
    super.key,
    this.onEventCreated,
  });

  @override
  State<EventCreationScreen> createState() => _EventCreationScreenState();
}

class _EventCreationScreenState extends State<EventCreationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _eventService = EventService();
  final _rsoService = RSOService();
  bool _isLoading = false;
  bool _isLoadingRSOs = true;
  List<Map<String, dynamic>> _userRSOs = [];
  String? _selectedRSOId;

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _priceController = TextEditingController();
  
  DateTime _startTime = DateTime.now();
  DateTime _endTime = DateTime.now().add(const Duration(hours: 1));

  @override
  void initState() {
    super.initState();
    _loadUserRSOs();
  }

  Future<void> _selectDateTime(BuildContext context, bool isStartTime) async {
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: isStartTime ? _startTime : _endTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null) {
      final TimeOfDay? time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(isStartTime ? _startTime : _endTime),
      );

      if (time != null && mounted) {
        setState(() {
          final newDateTime = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
          
          if (isStartTime) {
            _startTime = newDateTime;
            // Automatically adjust end time if it's before start time
            if (_endTime.isBefore(_startTime)) {
              _endTime = _startTime.add(const Duration(hours: 1));
            }
          } else {
            if (newDateTime.isBefore(_startTime)) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('End time must be after start time'),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }
            _endTime = newDateTime;
          }
        });
      }
    }
  }

  Future<void> _loadUserRSOs() async {
    try {
      final rsos = await _rsoService.getUserRSOs();
      if (mounted) {
        setState(() {
          _userRSOs = rsos;
          _isLoadingRSOs = false;
          if (rsos.isNotEmpty) {
            _selectedRSOId = rsos.first['id'];
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading RSOs: ${e.toString()}')),
        );
        setState(() => _isLoadingRSOs = false);
      }
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate() && _selectedRSOId != null) {
      setState(() => _isLoading = true);
      try {
        await _eventService.createEvent(
          title: _titleController.text,
          description: _descriptionController.text,
          location: _locationController.text,
          startTime: _startTime,
          endTime: _endTime,
          rsoId: _selectedRSOId!,
          price: _priceController.text.isNotEmpty
              ? double.parse(_priceController.text)
              : null,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Event created successfully!')),
          );
          widget.onEventCreated?.call();
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error creating event: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingRSOs) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_userRSOs.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Create New Event'),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'You need to register an RSO before you can create events.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Event'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                value: _selectedRSOId,
                decoration: const InputDecoration(
                  labelText: 'Select RSO',
                  border: OutlineInputBorder(),
                ),
                items: _userRSOs.map<DropdownMenuItem<String>>((rso) {
                  return DropdownMenuItem<String>(
                    value: rso['id'] as String,
                    child: Text(rso['name'] as String),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedRSOId = value;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select an RSO';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Event Title',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an event title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a description';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Location',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a location';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('Start Time'),
                subtitle: Text(DateFormat('MMM d, y HH:mm').format(_startTime)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _selectDateTime(context, true),
              ),
              ListTile(
                title: const Text('End Time'),
                subtitle: Text(DateFormat('MMM d, y HH:mm').format(_endTime)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _selectDateTime(context, false),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: 'Price (Optional)',
                  border: OutlineInputBorder(),
                  prefixText: '\$',
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    if (double.tryParse(value) == null) {
                      return 'Please enter a valid price';
                    }
                    if (double.parse(value) < 0) {
                      return 'Price cannot be negative';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _submitForm,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Create Event'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _priceController.dispose();
    super.dispose();
  }
} 