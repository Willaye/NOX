class AppConstants {
  static const String appName = 'NOX';
  static const String apiBaseUrl = 'https://nox-backend-production-ea47.up.railway.app/api';
  static const String wsUrl = 'https://nox-backend-production-ea47.up.railway.app';
  static const String wsNamespace = '/nox-mdm';
  static const Duration syncInterval = Duration(minutes: 5);
  static const Duration locationInterval = Duration(seconds: 30);
  static const Duration heartbeatInterval = Duration(minutes: 1);
}
