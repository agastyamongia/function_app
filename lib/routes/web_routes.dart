import 'package:flutter/material.dart';
import '../screens/event_registration_screen.dart';

class WebRoutes {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    // Extract the event ID from the URL path
    // Expected format: /event/register/:eventId
    final uri = Uri.parse(settings.name ?? '');
    final pathSegments = uri.pathSegments;

    if (pathSegments.length == 3 && 
        pathSegments[0] == 'event' && 
        pathSegments[1] == 'register') {
      final eventId = pathSegments[2];
      return MaterialPageRoute(
        builder: (context) => EventRegistrationScreen(eventId: eventId),
      );
    }

    // Default route or 404
    return MaterialPageRoute(
      builder: (context) => Scaffold(
        appBar: AppBar(title: const Text('Page Not Found')),
        body: const Center(
          child: Text('The requested page was not found.'),
        ),
      ),
    );
  }
} 