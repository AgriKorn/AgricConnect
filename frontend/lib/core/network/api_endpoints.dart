/// All backend endpoint paths for AgriConnect API.
class ApiEndpoints {
  ApiEndpoints._();

  static const String defaultBaseUrl = 'https://container-service-1.veg2jxqsfecbm.eu-west-1.cs.amazonlightsail.com/api';

  // Auth Endpoints
  static const String authRegister = '/auth/register';
  static const String authLogin = '/auth/login';
  static const String authVerifyOtp = '/auth/verify-otp';
  static const String authForgotPassword = '/auth/forgot-password';
  static const String authResetPassword = '/auth/reset-password';
  static const String authRefresh = '/auth/refresh';
  static const String authLogout = '/auth/logout';
  static const String authGoogle = '/auth/google';

  // User & Profile Endpoints
  static const String userProfile = '/users/profile';
  static const String userDeviceToken = '/users/device-token';
  static const String userAddresses = '/users/addresses';

  // Dispatch (driver job offers)
  static const String dispatchJobs = '/dispatch/jobs';

  // Produce Listings (farmer-only create/list)
  static const String listings = '/listings';

  // Marketplace (public browse/detail — what buyers see)
  static const String marketplace = '/marketplace';

  // Transactions & Escrow
  static const String transactions = '/transactions';
  static const String transactionPurchase = '/transactions/purchase';

  // Disputes
  static const String disputes = '/disputes';

  // Payments (Paystack)
  static const String paystackResolveMomo = '/payments/paystack/resolve-momo';

  // Storage
  static const String s3PresignedUrl = '/s3/presigned-url';

  // System
  static const String health = '/health';
}
