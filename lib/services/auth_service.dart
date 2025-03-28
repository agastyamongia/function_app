import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final _config = AppConfig.instance;
  
  /// Format phone number to E.164 format
  String _formatPhoneNumber(String phoneNumber) {
    // Remove any non-digit characters
    String cleaned = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    
    // Add US country code if not present
    if (cleaned.length == 10) {
      return '+1$cleaned';
    } else if (cleaned.length == 11 && cleaned.startsWith('1')) {
      return '+$cleaned';
    }
    
    // If already in E.164 format, return as is
    if (phoneNumber.startsWith('+')) {
      return phoneNumber;
    }
    
    throw Exception('Invalid phone number format. Please enter a 10-digit US phone number.');
  }

  /// Send OTP to phone number using Supabase
  Future<void> sendOTP(String phoneNumber) async {
    try {
      // Format phone number to E.164 format
      phoneNumber = _formatPhoneNumber(phoneNumber);
      
      print('Sending verification to: $phoneNumber');
      
      // Send OTP through Supabase
      await _supabase.auth.signInWithOtp(
        phone: phoneNumber,
      );

      print('OTP sent successfully');
    } catch (e) {
      print('Error sending OTP: $e');
      throw Exception('Failed to send verification code: $e');
    }
  }

  /// Verify OTP and sign in or sign up user
  Future<AuthResponse> verifyOTPAndSignIn(String phoneNumber, String otp) async {
    try {
      // Format phone number to E.164 format
      phoneNumber = _formatPhoneNumber(phoneNumber);
      
      print('Verifying OTP for: $phoneNumber');

      // Verify OTP with Supabase
      final response = await _supabase.auth.verifyOTP(
        phone: phoneNumber,
        token: otp,
        type: OtpType.sms,
      );

      print('Verification successful');

      // If this is a new user, create their profile
      final existingProfile = await _supabase
          .from('profiles')
          .select('id')
          .eq('phone_number', phoneNumber)
          .maybeSingle();

      if (existingProfile == null && response.user != null) {
        await _supabase.from('profiles').insert({
          'id': response.user!.id,
          'phone_number': phoneNumber,
          'created_at': DateTime.now().toIso8601String(),
        });
        print('Created new user profile');
      }

      return response;
    } catch (e) {
      print('Error verifying OTP: $e');
      throw Exception('Failed to verify code: $e');
    }
  }

  /// Sign out the current user
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  /// Get the current user's session
  Session? getCurrentSession() {
    return _supabase.auth.currentSession;
  }

  /// Get the current user
  User? getCurrentUser() {
    return _supabase.auth.currentUser;
  }

  /// Listen to auth state changes
  Stream<AuthState> get onAuthStateChange => _supabase.auth.onAuthStateChange;
} 