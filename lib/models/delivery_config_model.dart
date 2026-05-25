class DeliveryConfig {
  final double baseDeliveryFee;
  final double multiVendorBaseDeliveryFee;
  final double subsidyRate;
  final double distanceRate;
  final double freeDistanceKm;
  final double maxSubsidyCap;

  const DeliveryConfig({
    this.baseDeliveryFee = 20.0,
    this.multiVendorBaseDeliveryFee = 25.0,
    this.subsidyRate = 0.07,
    this.distanceRate = 7.0,
    this.freeDistanceKm = 2.0,
    this.maxSubsidyCap = 35.0,
  });

  factory DeliveryConfig.fromMap(Map<String, dynamic> map) {
    return DeliveryConfig(
      baseDeliveryFee: (map['baseDeliveryFee'] as num?)?.toDouble() ?? 20.0,
      multiVendorBaseDeliveryFee:
          (map['multiVendorBaseDeliveryFee'] as num?)?.toDouble() ?? 25.0,
      subsidyRate: (map['subsidyRate'] as num?)?.toDouble() ?? 0.07,
      distanceRate: (map['distanceRate'] as num?)?.toDouble() ?? 7.0,
      freeDistanceKm: (map['freeDistanceKm'] as num?)?.toDouble() ?? 2.0,
      maxSubsidyCap: (map['maxSubsidyCap'] as num?)?.toDouble() ?? 35.0,
    );
  }
}
