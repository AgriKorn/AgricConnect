/// All backend endpoint paths (claude.md Backend Integration Reference).
/// Auth paths are illustrative until that contract is confirmed — see
/// AuthRepository. `pricingRecommend` is a real, verified contract (see
/// backend/src/modules/pricing/pricing.routes.ts + pricing.schema.ts).
class ApiEndpoints {
  ApiEndpoints._();

  static const authRegister = '/auth/register';
  static const authLogin = '/auth/login';

  /// GET, query params: crop, region, freshness, shelfLifeDays? — see
  /// PricingRepository.
  static const pricingRecommend = '/pricing/recommend';
}
