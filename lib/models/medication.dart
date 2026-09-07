class Medication {
  final String id;
  final String patientId;
  final String name;
  final String? genericName;
  final String? strength;
  final String? dosageForm;
  final String? instructions;
  final String? imageUrl;
  final DateTime startDate;
  final DateTime? endDate;
  final bool active;
  final String createdBy;
  final DateTime createdAt;
  final bool stockEnabled;
  final double stockQuantity;
  final String stockUnit;
  final double? packageQuantity;
  final double lowStockThreshold;

  const Medication({
    required this.id,
    required this.patientId,
    required this.name,
    this.genericName,
    this.strength,
    this.dosageForm,
    this.instructions,
    this.imageUrl,
    required this.startDate,
    this.endDate,
    required this.active,
    required this.createdBy,
    required this.createdAt,
    this.stockEnabled = false,
    this.stockQuantity = 0,
    this.stockUnit = 'unit',
    this.packageQuantity,
    this.lowStockThreshold = 5,
  });

  factory Medication.fromMap(Map<String, dynamic> map) {
    return Medication(
      id: map['id'] as String,
      patientId: map['patient_id'] as String,
      name: map['name'] as String,
      genericName: map['generic_name'] as String?,
      strength: map['strength'] as String?,
      dosageForm: map['dosage_form'] as String?,
      instructions: map['instructions'] as String?,
      imageUrl: map['image_url'] as String?,
      startDate: DateTime.parse(map['start_date'] as String),
      endDate: map['end_date'] != null ? DateTime.parse(map['end_date'] as String) : null,
      active: map['active'] as bool? ?? true,
      createdBy: map['created_by'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      stockEnabled: map['stock_enabled'] as bool? ?? false,
      stockQuantity: (map['stock_quantity'] as num?)?.toDouble() ?? 0,
      stockUnit: map['stock_unit'] as String? ?? 'unit',
      packageQuantity: (map['package_quantity'] as num?)?.toDouble(),
      lowStockThreshold: (map['low_stock_threshold'] as num?)?.toDouble() ?? 5,
    );
  }

  Map<String, dynamic> toInsertMap() => {
        'patient_id': patientId,
        'name': name,
        'generic_name': genericName,
        'strength': strength,
        'dosage_form': dosageForm,
        'instructions': instructions,
        'image_url': imageUrl,
        'start_date': startDate.toIso8601String().split('T').first,
        'end_date': endDate?.toIso8601String().split('T').first,
        'active': active,
        'created_by': createdBy,
        'stock_enabled': stockEnabled,
        'stock_quantity': 0,
        'stock_unit': stockUnit,
        'package_quantity': packageQuantity,
        'low_stock_threshold': lowStockThreshold,
      };
}