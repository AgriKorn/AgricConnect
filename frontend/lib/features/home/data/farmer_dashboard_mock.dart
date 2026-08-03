/// Shape returned by GET /listings, mapped in marketplace_repository.dart —
/// despite the file name this is real, not mock (dashboard/profile figures
/// live in farmer_dashboard_repository.dart now).
class FarmerListingSummary {
  const FarmerListingSummary({
    required this.id,
    required this.cropType,
    required this.freshnessScore,
    required this.price,
    required this.unit,
    required this.status,
    this.qrCodeData,
    this.imageAsset,
    this.imageUrl,
  });

  final String id;
  final String cropType;
  final int freshnessScore;
  final double price;
  final String unit;
  final String status; // Active | Pending | Sold
  final String? qrCodeData; // data:image/png;base64,... shown to buyers/drivers at delivery
  final String? imageAsset; // bundled asset — unused by real listings, kept for any future seed/demo data
  final String? imageUrl; // real S3 photo the farmer uploaded, if any
}
