import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/event.dart';

class EventService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<Event> createEvent({
    required String rsoId,
    required String title,
    required String description,
    required DateTime startTime,
    required DateTime endTime,
    required String location,
    double? price,
    String? qrCodeUrl,
    String? shareableLink,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User must be logged in to create an event');
      }

      // Generate a unique shareable link
      final uniqueId = DateTime.now().millisecondsSinceEpoch.toString();
      final generatedShareableLink = '/event/$uniqueId';

      final response = await _supabase.from('events').insert({
        'rso_id': rsoId,
        'title': title,
        'description': description,
        'start_time': startTime.toIso8601String(),
        'end_time': endTime.toIso8601String(),
        'location': location,
        'price': price,
        'created_at': DateTime.now().toIso8601String(),
        'is_published': false,
        'qr_code_url': qrCodeUrl,
        'shareable_link': generatedShareableLink,
        'creator_id': userId,
      }).select().single();

      return Event.fromMap(response);
    } catch (e) {
      throw Exception('Failed to create event: $e');
    }
  }

  Future<Event?> getEvent(String id) async {
    try {
      final response = await _supabase
          .from('events')
          .select()
          .eq('id', id)
          .single();

      return Event.fromMap(response);
    } catch (e) {
      return null;
    }
  }

  Future<List<Event>> getEventsByRSO(String rsoId) async {
    try {
      final response = await _supabase
          .from('events')
          .select()
          .eq('rso_id', rsoId)
          .order('start_time', ascending: true);

      return response.map((json) => Event.fromMap(json)).toList();
    } catch (e) {
      throw Exception('Failed to fetch events: $e');
    }
  }

  /// Get all events created by the current user
  Future<List<Event>> getUserEvents() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User must be logged in to fetch their events');
      }

      final response = await _supabase
          .from('events')
          .select('''
            *,
            rso:rsos (
              name,
              description
            )
          ''')
          .eq('creator_id', userId)
          .order('rso_id');

      return response.map<Event>((event) => Event.fromMap({
        ...event,
        'rso_name': event['rso']['name'], // Add RSO name to the event data
      })).toList();
    } catch (e) {
      throw Exception('Failed to fetch user events: $e');
    }
  }

  Future<List<Event>> getUpcomingEvents() async {
    try {
      final now = DateTime.now().toIso8601String();
      final response = await _supabase
          .from('events')
          .select()
          .gte('start_time', now)
          .eq('is_published', true)
          .order('start_time', ascending: true);

      return response.map((json) => Event.fromMap(json)).toList();
    } catch (e) {
      throw Exception('Failed to fetch upcoming events: $e');
    }
  }

  Future<void> updateEvent(String eventId, Map<String, dynamic> updates) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User must be logged in to update an event');
      }

      await _supabase
          .from('events')
          .update(updates)
          .eq('id', eventId);
    } catch (e) {
      throw Exception('Failed to update event: $e');
    }
  }

  Future<void> publishEvent(String eventId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User must be logged in to publish an event');
      }

      // Verify the user owns this event
      final event = await getEvent(eventId);
      if (event == null || event.creatorId != userId) {
        throw Exception('You do not have permission to publish this event');
      }

      await _supabase
          .from('events')
          .update({'is_published': true})
          .eq('id', eventId);
    } catch (e) {
      throw Exception('Failed to publish event: $e');
    }
  }

  Future<void> deleteEvent(String eventId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User must be logged in to delete an event');
      }

      // Verify the user owns this event
      final event = await getEvent(eventId);
      if (event == null || event.creatorId != userId) {
        throw Exception('You do not have permission to delete this event');
      }

      await _supabase
          .from('events')
          .delete()
          .eq('id', eventId);
    } catch (e) {
      throw Exception('Failed to delete event: $e');
    }
  }

  /// Get analytics data for an event including registration count, revenue, and registered users
  Future<Map<String, dynamic>> getEventAnalytics(String eventId) async {
    try {
      // First get the registrations
      final registrations = await _supabase
          .from('event_registrations')
          .select()
          .eq('event_id', eventId);

      // Calculate total revenue and format user data
      double totalRevenue = 0;
      final List<Map<String, dynamic>> registeredUsers = [];

      // Get user profiles for all registered users
      for (final registration in registrations) {
        try {
          // Get the user's profile
          final profileResponse = await _supabase
              .from('profiles')
              .select()
              .eq('id', registration['user_id'])
              .single();

          if (profileResponse != null) {
            registeredUsers.add({
              'name': '${profileResponse['first_name']} ${profileResponse['last_name']}',
              'email': profileResponse['email'],
              'registered_at': registration['created_at'],
            });
          }

          // Add to revenue if the event has a price
          if (registration['amount_paid'] != null) {
            totalRevenue += (registration['amount_paid'] as num).toDouble();
          }
        } catch (e) {
          // Skip this user if profile fetch fails
          continue;
        }
      }

      return {
        'registeredCount': registrations.length,
        'totalRevenue': totalRevenue,
        'registeredUsers': registeredUsers,
      };
    } catch (e) {
      throw 'Failed to load event analytics: $e';
    }
  }

  /// Register a user for an event
  Future<void> registerForEvent(String eventId) async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final event = await getEvent(eventId);

      // Check if user is already registered
      final existingRegistration = await _supabase
          .from('event_registrations')
          .select()
          .eq('event_id', eventId)
          .eq('user_id', userId)
          .maybeSingle();

      if (existingRegistration != null) {
        throw 'You are already registered for this event';
      }

      // Create registration record
      await _supabase.from('event_registrations').insert({
        'event_id': eventId,
        'user_id': userId,
        'amount_paid': event?.price,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw 'Failed to register for event: $e';
    }
  }

  /// Cancel a user's registration for an event
  Future<void> cancelRegistration(String eventId) async {
    try {
      final userId = _supabase.auth.currentUser!.id;

      await _supabase
          .from('event_registrations')
          .delete()
          .eq('event_id', eventId)
          .eq('user_id', userId);
    } catch (e) {
      throw 'Failed to cancel registration: $e';
    }
  }

  /// Check if a user is registered for an event
  Future<bool> isUserRegistered(String eventId) async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final registration = await _supabase
          .from('event_registrations')
          .select()
          .eq('event_id', eventId)
          .eq('user_id', userId)
          .maybeSingle();

      return registration != null;
    } catch (e) {
      throw 'Failed to check registration status: $e';
    }
  }
} 