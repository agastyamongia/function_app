import 'package:supabase_flutter/supabase_flutter.dart';

class RSOAdminService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Add a new admin to an RSO
  Future<void> addAdmin(String rsoId, String userId) async {
    try {
      await _supabase.from('rso_admins').insert({
        'rso_id': rsoId,
        'user_id': userId,
      });
    } catch (e) {
      throw Exception('Failed to add admin: $e');
    }
  }

  /// Remove an admin from an RSO
  Future<void> removeAdmin(String rsoId, String userId) async {
    try {
      await _supabase
          .from('rso_admins')
          .delete()
          .eq('rso_id', rsoId)
          .eq('user_id', userId);
    } catch (e) {
      throw Exception('Failed to remove admin: $e');
    }
  }

  /// Get all admins for an RSO
  Future<List<Map<String, dynamic>>> getRSOAdmins(String rsoId) async {
    try {
      final response = await _supabase
          .from('rso_admins')
          .select('''
            user_id,
            users:user_id (
              email
            )
          ''')
          .eq('rso_id', rsoId);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to fetch RSO admins: $e');
    }
  }

  /// Check if a user is an admin of an RSO
  Future<bool> isUserAdmin(String rsoId, String userId) async {
    try {
      final response = await _supabase
          .from('rso_admins')
          .select()
          .eq('rso_id', rsoId)
          .eq('user_id', userId)
          .maybeSingle();
      
      return response != null;
    } catch (e) {
      throw Exception('Failed to check admin status: $e');
    }
  }

  /// Get all RSOs where the current user is an admin
  Future<List<Map<String, dynamic>>> getUserAdminRSOs() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User must be logged in');
      }

      final response = await _supabase
          .from('rso_admins')
          .select('''
            rso_id,
            rsos:rso_id (
              id,
              name,
              description,
              email,
              phone_number,
              website_url,
              social_media_url,
              created_at
            )
          ''')
          .eq('user_id', userId);
      
      return response.map((admin) => admin['rsos'] as Map<String, dynamic>).toList();
    } catch (e) {
      throw Exception('Failed to fetch user admin RSOs: $e');
    }
  }
} 