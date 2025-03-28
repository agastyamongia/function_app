// Copy this file to app_config.dart and replace the values with your actual credentials
class AppConfig {
  static final AppConfig instance = AppConfig._();
  AppConfig._();

  // Twilio configuration
  final String twilioAccountSid = 'your_account_sid_here';
  final String twilioApiKey = 'your_api_key_here';
  final String twilioApiSecret = 'your_api_secret_here';
  final String twilioServiceSid = 'your_service_sid_here';
} 