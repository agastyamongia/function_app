class Env {
  static const String twilioAccountSid = String.fromEnvironment(
    'TWILIO_ACCOUNT_SID',
    defaultValue: '',
  );
  
  static const String twilioApiKey = String.fromEnvironment(
    'TWILIO_API_KEY',
    defaultValue: '',
  );
  
  static const String twilioApiSecret = String.fromEnvironment(
    'TWILIO_API_SECRET',
    defaultValue: '',
  );
  
  static const String twilioServiceSid = String.fromEnvironment(
    'TWILIO_SERVICE_SID',
    defaultValue: '',
  );
} 