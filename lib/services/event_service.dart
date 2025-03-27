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
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User must be logged in to create an event');
      }

      // Get RSO name first
      final rsoResponse = await _supabase
          .from('rsos')
          .select('name')
          .eq('id', rsoId)
          .single();
      
      final rsoName = rsoResponse['name'] as String;

      // Create the event first to get its ID
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
        'creator_id': userId,
      }).select().single();

      // Update the event with its shareable link using its actual ID
      final eventId = response['id'];
      final shareableLink = 'https://functionapp.vercel.app/events/$eventId';
      
      await _supabase
          .from('events')
          .update({'shareable_link': shareableLink})
          .eq('id', eventId);

      // Add RSO name to the response before creating Event object
      return Event.fromMap({
        ...response,
        'rso_name': rsoName,
        'shareable_link': shareableLink,
      });
    } catch (e) {
      throw Exception('Failed to create event: $e');
    }
  }

  Future<Event?> getEvent(String id) async {
    try {
      final response = await _supabase
          .from('events')
          .select('''
            *,
            rsos!inner (
              name
            )
          ''')
          .eq('id', id)
          .single();

      if (response == null) return null;

      // Safely extract RSO name with null check
      final rsoName = response['rsos'] != null ? response['rsos']['name'] : null;
      if (rsoName == null) {
        print('Warning: RSO name is null for event $id');
      }

      // Create a clean map without the nested rsos object
      final eventMap = {
        ...response,
        'rso_name': rsoName ?? 'Unknown RSO', // Provide a default value
      };
      // Remove the nested rsos object to avoid conflicts
      eventMap.remove('rsos');

      return Event.fromMap(eventMap);
    } catch (e) {
      print('Error fetching event: $e');
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
            rsos!inner (
              name
            )
          ''')
          .eq('creator_id', userId)
          .order('rso_id');

      return response.map<Event>((event) {
        // Safely extract RSO name with null check
        final rsoName = event['rsos'] != null ? event['rsos']['name'] : null;
        
        // Create a clean map without the nested rsos object
        final eventMap = {
          ...event,
          'rso_name': rsoName ?? 'Unknown RSO',
        };
        eventMap.remove('rsos');
        
        return Event.fromMap(eventMap);
      }).toList();
    } catch (e) {
      print('Error fetching user events: $e');
      return [];
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

      // Process registrations and fetch profiles
      for (final registration in registrations) {
        try {
          // Get the user's profile
          final profileResponse = await _supabase
              .from('profiles')
              .select('full_name, phone_number')
              .eq('id', registration['user_id'])
              .maybeSingle();

          // Only add to registered users if we have valid profile data
          if (profileResponse != null && 
              profileResponse['full_name'] != null && 
              profileResponse['phone_number'] != null) {
            registeredUsers.add({
              'name': profileResponse['full_name'],
              'phone': profileResponse['phone_number'],
              'registered_at': registration['created_at'] ?? DateTime.now().toIso8601String(),
            });
          }

          // Add to revenue if the event has a price
          final amountPaid = registration['amount_paid'];
          if (amountPaid != null) {
            totalRevenue += (amountPaid as num).toDouble();
          }
        } catch (e) {
          print('Error fetching profile for registration: $e');
          continue;
        }
      }

      return {
        'registeredCount': registrations.length,
        'totalRevenue': totalRevenue,
        'registeredUsers': registeredUsers,
      };
    } catch (e) {
      print('Failed to load event analytics: $e');
      return {
        'registeredCount': 0,
        'totalRevenue': 0.0,
        'registeredUsers': [],
      };
    }
  }

  /// Check if a phone number exists in profiles
  Future<Map<String, dynamic>?> findUserByPhone(String phoneNumber) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('id, full_name, phone_number')
          .eq('phone_number', phoneNumber)
          .maybeSingle();
      return response;
    } catch (e) {
      throw 'Failed to find user: $e';
    }
  }

  /// Create a new user and profile
  Future<Map<String, dynamic>> createNewUser({
    required String phoneNumber,
    required String fullName,
  }) async {
    try {
      // Create a new user in auth.users with metadata
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final email = 'user_$timestamp@temp.com';
      final password = 'temp_${timestamp}_pwd';
      
      // Include user metadata that will be used by the trigger
      final authResponse = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
          'phone_number': phoneNumber,
        }
      );

      if (authResponse.user == null) {
        throw 'Failed to create user account';
      }

      // The trigger will have created the profile, but let's update it to ensure data is correct
      final profile = await _supabase
          .from('profiles')
          .update({
            'full_name': fullName,
            'phone_number': phoneNumber,
          })
          .eq('id', authResponse.user!.id)
          .select()
          .single();

      return profile;
    } catch (e) {
      throw 'Failed to create user and profile: $e';
    }
  }

  /// Register for an event using phone number
  Future<void> registerForEventWithPhone({
    required String eventId,
    required String phoneNumber,
    String? fullName,
  }) async {
    try {
      // Check if user exists by phone number
      final existingUser = await findUserByPhone(phoneNumber);
      String userId;

      if (existingUser != null) {
        // Use existing user's ID - no need to update name for existing users
        userId = existingUser['id'];
      } else {
        if (fullName == null) {
          throw 'Name is required for new registration';
        }
        // Create new user with profile
        final newUser = await createNewUser(
          phoneNumber: phoneNumber,
          fullName: fullName,
        );
        userId = newUser['id'];
      }

      // Check if already registered
      final existingRegistration = await _supabase
          .from('event_registrations')
          .select()
          .eq('event_id', eventId)
          .eq('user_id', userId)
          .maybeSingle();

      if (existingRegistration != null) {
        throw 'This phone number is already registered for this event';
      }

      // Create registration
      await _supabase.from('event_registrations').insert({
        'event_id': eventId,
        'user_id': userId,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw 'Failed to register for event: $e';
    }
  }
} 