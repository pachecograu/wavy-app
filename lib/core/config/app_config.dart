class AppConfig {
  // AWS Application Load Balancer URL (producción)
  static const String _productionUrl = 'https://wavy-alb-1189004548.us-east-1.elb.amazonaws.com';
  
  static String get backendUrl => _productionUrl;
  
  // Socket.IO para realtime
  static String get socketUrl => backendUrl;
  static String get apiUrl => '$backendUrl/api';
}