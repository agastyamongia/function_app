import 'package:supabase_flutter/supabase_flutter.dart';

class RSOService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<Map<String, dynamic>> createRSO({
    required String name,
    required String description,
    required String email,
    required String phoneNumber,
    String? websiteUrl,
    String? socialMediaUrl,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User must be logged in to create an RSO');
      }

      final response = await _supabase.from('rsos').insert({
        'name': name,
        'description': description,
        'email': email,
        'phone_number': phoneNumber,
        'website_url': websiteUrl,
        'social_media_url': socialMediaUrl,
        'creator_id': userId,
        'created_at': DateTime.now().toIso8601String(),
        'is_active': true,
      }).select().single();

      return response;
    } catch (e) {
      throw Exception('Failed to create RSO: $e');
    }
  }

  Future<Map<String, dynamic>?> getRSO(String id) async {
    try {
      final response = await _supabase
          .from('rsos')
          .select()
          .eq('id', id)
          .single();

      return response;
    } catch (e) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getAllRSOs() async {
    try {
      final response = await _supabase
          .from('rsos')
          .select()
          .eq('is_active', true)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to fetch RSOs: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getUserRSOs() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User must be logged in to fetch their RSOs');
      }

      final response = await _supabase
          .from('rsos')
          .select()
          .eq('creator_id', userId)
          .eq('is_active', true)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to fetch user RSOs: $e');
    }
  }

  Future<void> updateRSO(String id, Map<String, dynamic> updates) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User must be logged in to update an RSO');
      }

      // Verify the user owns this RSO
      final rso = await getRSO(id);
      if (rso == null || rso['creator_id'] != userId) {
        throw Exception('You do not have permission to update this RSO');
      }

      await _supabase
          .from('rsos')
          .update(updates)
          .eq('id', id);
    } catch (e) {
      throw Exception('Failed to update RSO: $e');
    }
  }

  Future<void> deleteRSO(String id) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User must be logged in to delete an RSO');
      }

      // Verify the user owns this RSO
      final rso = await getRSO(id);
      if (rso == null || rso['creator_id'] != userId) {
        throw Exception('You do not have permission to delete this RSO');
      }

      await _supabase
          .from('rsos')
          .update({'is_active': false})
          .eq('id', id);
    } catch (e) {
      throw Exception('Failed to delete RSO: $e');
    }
  }
} 