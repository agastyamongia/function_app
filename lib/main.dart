import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/login_screen.dart';
import 'services/rso_service.dart';
import 'services/event_service.dart';
import 'screens/rso_registration_screen.dart';
import 'screens/event_creation_screen.dart';
import 'package:intl/intl.dart';
import 'models/event.dart';
import 'screens/event_details_screen.dart';
import 'routes/web_routes.dart';
import 'screens/event_registration_screen.dart';

/// Initializes the Supabase client and starts the application
// main function
Future<void> main() async {
  await Supabase.initialize(
    url: 'https://eolsgonqepuyolaagmsl.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVvbHNnb25xZXB1eW9sYWFnbXNsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDIxNjgzNjAsImV4cCI6MjA1Nzc0NDM2MH0.KxmVx0DZv9ewrKIfNP5FdggPTeaB_BGhk5L3XTJL6M8'
  );
  runApp(const MyApp());
}

/// Root widget of the application that sets up the theme and initial route
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Check if we're accessing an event registration page
    final isEventRegistration = Uri.base.pathSegments.length >= 2 && 
                              Uri.base.pathSegments[0] == 'events';

    return MaterialApp(
      title: 'RSO Events',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      onGenerateRoute: WebRoutes.generateRoute,
      initialRoute: Uri.base.path,
      // Use EventRegistrationScreen for registration links, AuthWrapper for everything else
      home: isEventRegistration
          ? EventRegistrationScreen(eventId: Uri.base.pathSegments[1])
          : const AuthWrapper(),
    );
  }
}

/// Wrapper widget that handles authentication state and navigation
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    _setupAuthListener();
    _checkCurrentSession();
  }

  /// Checks if there's an existing session when the app starts
  Future<void> _checkCurrentSession() async {
    final session = await Supabase.instance.client.auth.currentSession;
    if (session != null && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const MyHomePage(title: 'Function')),
      );
    }
  }

  /// Sets up a listener for authentication state changes
  void _setupAuthListener() {
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      final Session? session = data.session;
      
      if (!mounted) return;

      if (event == AuthChangeEvent.signedIn && session != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Successfully signed in!')),
        );
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const MyHomePage(title: 'Function')),
        );
      } else if (event == AuthChangeEvent.signedOut) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Successfully signed out')),
        );
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text('Error: ${snapshot.error}'),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.active) {
          final session = snapshot.data?.session;
          return session != null
              ? const MyHomePage(title: 'Function')
              : const LoginScreen();
        }

        // Loading state
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );
      },
    );
  }
}

/// Main home page of the application after authentication
class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final _rsoService = RSOService();
  final _eventService = EventService();
  List<Map<String, dynamic>> _userRSOs = [];
  List<Event> _userEvents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// Fetches both RSOs and user events
  Future<void> _loadData() async {
    try {
      final rsosData = _rsoService.getUserRSOs();
      final userEventsData = _eventService.getUserEvents();
      
      final results = await Future.wait([rsosData, userEventsData]);
      
      if (mounted) {
        setState(() {
          _userRSOs = results[0] as List<Map<String, dynamic>>;
          _userEvents = results[1] as List<Event>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    }
  }

  /// Handles user logout and navigation to login screen
  Future<void> _handleLogout() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  /// Navigates to RSO registration screen
  void _navigateToRSORegistration() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RSORegistrationScreen(
          onRSORegistered: _loadData,
        ),
      ),
    );
  }

  /// Navigates to event creation screen
  void _navigateToEventCreation() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EventCreationScreen(
          onEventCreated: _loadData,
        ),
      ),
    );
  }

  Future<void> _publishEvent(Event event) async {
    try {
      await _eventService.publishEvent(event.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event published successfully!')),
        );
        _loadData();  // Refresh data after publishing
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error publishing event: $e')),
        );
      }
    }
  }

  Widget _buildEventCard(Event event, {bool isUserEvent = false}) {
    final bool canPublish = isUserEvent && !event.isPublished;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            debugPrint('Navigating to event details: ${event.id}');
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => EventDetailsScreen(
                  event: event,
                  isOwner: isUserEvent,
                  onEventUpdated: _loadData,
                ),
              ),
            );
            if (mounted) {
              _loadData();
            }
          },
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: isUserEvent ? Colors.blue.withOpacity(0.3) : Colors.transparent,
                width: 1,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              event.title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Hosted by ${event.rsoName}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!event.isPublished)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Draft',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    event.description,
                    style: Theme.of(context).textTheme.bodyMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('MMM d, y HH:mm').format(event.startTime),
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          event.location,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (event.price != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.attach_money, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          '\$${event.price?.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                  if (canPublish) ...[
                    const SizedBox(height: 16),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () => _publishEvent(event),
                          icon: const Icon(Icons.publish),
                          label: const Text('Publish'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEventsList() {
    // Group events by RSO
    final Map<String, List<Event>> eventsByRSO = {};
    for (final event in _userEvents) {
      if (!eventsByRSO.containsKey(event.rsoId)) {
        eventsByRSO[event.rsoId] = [];
      }
      eventsByRSO[event.rsoId]!.add(event);
    }

    if (_userEvents.isEmpty) {
      return const Center(
        child: Text('You haven\'t created any events yet'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: eventsByRSO.entries.map((entry) {
        final events = entry.value;
        final rsoName = events.first.rsoName;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                rsoName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ),
            ...events.map((event) => _buildEventCard(event, isUserEvent: true)),
            const SizedBox(height: 16),
          ],
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        leading: IconButton(
          icon: const Icon(Icons.logout),
          onPressed: _handleLogout,
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                const Text(
                  'Welcome to Function',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: _navigateToRSORegistration,
                  icon: const Icon(Icons.add),
                  label: const Text('Register An RSO'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _navigateToEventCreation,
                  icon: const Icon(Icons.event),
                  label: const Text('Create New Event'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Your RSOs',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                if (_userRSOs.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'You haven\'t registered any RSOs yet. Use the button above to register your first RSO!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  )
                else
                  ...List.generate(_userRSOs.length, (index) {
                    final rso = _userRSOs[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: ListTile(
                        title: Text(rso['name']),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(rso['description']),
                            const SizedBox(height: 4),
                            Text('Contact: ${rso['email']}'),
                          ],
                        ),
                        isThreeLine: true,
                        trailing: IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () {
                            // TODO: Implement RSO editing
                          },
                        ),
                      ),
                    );
                  }),
                const SizedBox(height: 32),
                const Text(
                  'Your Events',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _buildEventsList(),
              ],
            ),
    );
  }
}
