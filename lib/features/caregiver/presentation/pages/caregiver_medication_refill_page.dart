import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../models/medication.dart';
import '../../../medications/domain/stock_intelligence.dart';
import '../../../medications/presentation/providers/medication_provider.dart';

class CaregiverMedicationRefillPage extends StatefulWidget {
  final Medication medication;
  final String patientName;
  final bool canManageStock;

  const CaregiverMedicationRefillPage({
    super.key,
    required this.medication,
    required this.patientName,
    required this.canManageStock,
  });

  @override
  State<CaregiverMedicationRefillPage> createState() =>
      _CaregiverMedicationRefillPageState();
}

class _CaregiverMedicationRefillPageState
    extends State<CaregiverMedicationRefillPage> {
  late final MedicationProvider _provider;
  late Future<void> _loadFuture;
  final _quantityController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _provider = MedicationProvider();
    _loadFuture = _provider.load(widget.medication.patientId);
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _provider.dispose();
    super.dispose();
  }

  Medication get _medication {
    for (final medication in _provider.medications) {
      if (medication.id == widget.medication.id) return medication;
    }
    return widget.medication;
  }

  String _tr(String ar, String en, String fr) {
    switch (Localizations.localeOf(context).languageCode) {
      case 'en':
        return en;
      case 'fr':
        return fr;
      default:
        return ar;
    }
  }

  Future<void> _refill() async {
    if (!widget.canManageStock) return;

    final quantity = double.tryParse(
      _quantityController.text.trim().replaceAll(',', '.'),
    );
    if (quantity == null || quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr(
              'أدخل كمية صحيحة أكبر من صفر.',
              'Enter a valid quantity greater than zero.',
              'Saisissez une quantité valide supérieure à zéro.',
            ),
          ),
        ),
      );
      return;
    }

    final ok = await _provider.addMedicationStock(
      medication: _medication,
      quantity: quantity,
    );
    if (!mounted) return;

    if (ok) {
      _quantityController.clear();
      setState(() {
        _loadFuture = _provider.load(widget.medication.patientId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr(
              'تمت إضافة المخزون بنجاح.',
              'Stock refilled successfully.',
              'Stock réapprovisionné avec succès.',
            ),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _provider.error ??
                _tr(
                  'تعذّر تحديث المخزون.',
                  'Unable to update stock.',
                  'Impossible de mettre à jour le stock.',
                ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _tr('إدارة المخزون', 'Stock management', 'Gestion du stock'),
        ),
      ),
      body: FutureBuilder<void>(
        future: _loadFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingIndicator();
          }

          final medication = _medication;
          final days = StockIntelligence.daysRemaining(medication);
          final low = StockIntelligence.isLowStock(medication);
          final out = StockIntelligence.isOutOfStock(medication);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: .10),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.medication_rounded,
                          color: AppColors.primary,
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              medication.name,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.patientName,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            out
                                ? Icons.production_quantity_limits_rounded
                                : low
                                    ? Icons.warning_amber_rounded
                                    : Icons.inventory_2_rounded,
                            color: out || low
                                ? AppColors.danger
                                : AppColors.primary,
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              _tr(
                                'الحالة الحالية',
                                'Current stock',
                                'Stock actuel',
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          Text(
                            '${medication.stockQuantity} ${medication.stockUnit}',
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                      if (days != null) ...[
                        const SizedBox(height: 10),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(
                            _tr(
                              'يكفي تقريباً لـ $days يوماً',
                              'Approximately $days days remaining',
                              'Environ $days jours restants',
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              if (widget.canManageStock) ...[
                Text(
                  _tr('إضافة مخزون', 'Refill stock', 'Réapprovisionner'),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        TextField(
                          controller: _quantityController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: _tr(
                              'الكمية المضافة',
                              'Quantity to add',
                              'Quantité à ajouter',
                            ),
                            suffixText: medication.stockUnit,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _refill,
                            icon: const Icon(Icons.add_box_rounded),
                            label: Text(
                              _tr(
                                'إضافة إلى المخزون',
                                'Add to stock',
                                'Ajouter au stock',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.lock_outline_rounded),
                    title: Text(
                      _tr(
                        'المخزون للعرض فقط',
                        'Stock is view-only',
                        'Stock en lecture seule',
                      ),
                    ),
                    subtitle: Text(
                      _tr(
                        'لا تملك صلاحية تعديل مخزون هذا المريض.',
                        'You do not have permission to change this patient’s stock.',
                        'Vous n’avez pas l’autorisation de modifier ce stock.',
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
