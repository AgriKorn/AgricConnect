/// All backend endpoint paths for AgriConnect API.
class ApiEndpoints {
  ApiEndpoints._();

  static const String defaultBaseUrl = 'https://container-service-1.veg2jxqsfcbm.eu-west-1.cs.amazonlightsail.com/api';

  // Auth Endpoints
  static const String authRegister = '/auth/register';
  static const String authLogin = '/auth/login';
  static const String authVerifyOtp = '/auth/verify-otp';
  static const String authForgotPassword = '/auth/forgot-password';
  static const String authRefresh = '/auth/refresh';

  // User & Profile Endpoints
  static const String userProfile = '/users/profile';
  static const String userDeviceToken = '/users/device-token';

  // Produce Listings
  static const String listings = '/listings';

  // Transactions & Escrow
  static const String transactions = '/transactions';

  // Payments
  static const String paystackInitialize = '/payments/paystack/initialize';
  static const String paystackWebhook = '/payments/paystack/webhook';

  // Storage
  static const String s3PresignedUrl = '/s3/presigned-url';

  // System
  static const String health = '/health';
}
