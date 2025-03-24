import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/event.dart';
import '../services/event_service.dart';

class EventDetailsScreen extends StatefulWidget {
  final Event event;
  final bool isOwner;
  final Function() onEventUpdated;

  const EventDetailsScreen({
    super.key,
    required this.event,
    required this.isOwner,
    required this.onEventUpdated,
  });

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  final _eventService = EventService();
  bool _isLoading = true;
  bool _isEditing = false;
  int _registeredCount = 0;
  double _totalRevenue = 0;
  List<Map<String, dynamic>> _registeredUsers = [];

  // Controllers for editing
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _locationController;
  late TextEditingController _priceController;
  late DateTime _startTime;
  late DateTime _endTime;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadEventAnalytics();
  }

  void _initializeControllers() {
    _titleController = TextEditingController(text: widget.event.title);
    _descriptionController = TextEditingController(text: widget.event.description);
    _locationController = TextEditingController(text: widget.event.location);
    _priceController = TextEditingController(
      text: widget.event.price?.toStringAsFixed(2) ?? '',
    );
    _startTime = widget.event.startTime;
    _endTime = widget.event.endTime;
  }

  Future<void> _loadEventAnalytics() async {
    try {
      final analytics = await _eventService.getEventAnalytics(widget.event.id);
      if (mounted) {
        setState(() {
          _registeredCount = analytics['registeredCount'] ?? 0;
          _registeredUsers = List<Map<String, dynamic>>.from(analytics['registeredUsers'] ?? []);
          _totalRevenue = analytics['totalRevenue'] ?? 0.0;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading analytics: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
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

  Future<void> _saveChanges() async {
    try {
      setState(() => _isLoading = true);

      final updates = {
        'title': _titleController.text,
        'description': _descriptionController.text,
        'location': _locationController.text,
        'start_time': _startTime.toIso8601String(),
        'end_time': _endTime.toIso8601String(),
        'price': _priceController.text.isEmpty
            ? null
            : double.parse(_priceController.text),
      };

      await _eventService.updateEvent(widget.event.id, updates);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event updated successfully')),
        );
        setState(() => _isEditing = false);
        widget.onEventUpdated();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating event: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildEventDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_isEditing) ...[
          TextFormField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Event Title',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Description',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _locationController,
            decoration: const InputDecoration(
              labelText: 'Location',
              border: OutlineInputBorder(),
            ),
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
              labelText: 'Price',
              border: OutlineInputBorder(),
              prefixText: '\$',
            ),
            keyboardType: TextInputType.numberWithOptions(decimal: true),
          ),
        ] else ...[
          Text(
            widget.event.title,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            widget.event.description,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          _buildInfoRow(Icons.location_on, 'Location', widget.event.location),
          const SizedBox(height: 8),
          _buildInfoRow(
            Icons.calendar_today,
            'Date',
            DateFormat('EEEE, MMMM d, y').format(widget.event.startTime),
          ),
          const SizedBox(height: 8),
          _buildInfoRow(
            Icons.access_time,
            'Time',
            '${DateFormat('HH:mm').format(widget.event.startTime)} - ${DateFormat('HH:mm').format(widget.event.endTime)}',
          ),
          if (widget.event.price != null) ...[
            const SizedBox(height: 8),
            _buildInfoRow(
              Icons.attach_money,
              'Price',
              '\$${widget.event.price?.toStringAsFixed(2)}',
            ),
          ],
          if (widget.event.isPublished) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.link, size: 20, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'Shareable Link:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.event.shareableLink ?? 'No link available',
                    style: const TextStyle(
                      color: Colors.blue,
                      decoration: TextDecoration.underline,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: widget.event.shareableLink == null ? null : () {
                    Clipboard.setData(ClipboardData(
                      text: widget.event.shareableLink!,
                    ));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Link copied to clipboard!'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ],
      ],
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

  Widget _buildAnalyticsDashboard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Event Analytics',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildAnalyticsCard(
                    'Registered',
                    '$_registeredCount',
                    Icons.people,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildAnalyticsCard(
                    'Revenue',
                    '\$${_totalRevenue.toStringAsFixed(2)}',
                    Icons.attach_money,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Registered Users',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            if (_registeredUsers.isEmpty)
              const Text('No registrations yet')
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _registeredUsers.length,
                itemBuilder: (context, index) {
                  final user = _registeredUsers[index];
                  return ListTile(
                    leading: CircleAvatar(
                      child: Text(user['name'][0]),
                    ),
                    title: Text(user['name']),
                    subtitle: Text(user['email']),
                    trailing: Text(
                      DateFormat('MMM d, y').format(
                        DateTime.parse(user['registered_at']),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.blue),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Details'),
        actions: [
          if (widget.isOwner)
            IconButton(
              icon: Icon(_isEditing ? Icons.save : Icons.edit),
              onPressed: _isLoading
                  ? null
                  : () {
                      if (_isEditing) {
                        _saveChanges();
                      } else {
                        setState(() => _isEditing = true);
                      }
                    },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildEventDetails(),
                  const SizedBox(height: 32),
                  if (widget.isOwner) _buildAnalyticsDashboard(),
                ],
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