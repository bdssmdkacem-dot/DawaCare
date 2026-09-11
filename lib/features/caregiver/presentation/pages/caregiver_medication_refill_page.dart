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
          final schedules =
              _provider.schedulesByMedicationId[medication.id] ?? const [];
          final days = StockIntelligence.daysRemaining(
            medication: medication,
            schedules: schedules,
          );
          final low = StockIntelligence.isLowStock(medication);
          final out = StockIntelligence.isOutOfStock(medication);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
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
                      const SizedBox(height: 5),
                      Text(widget.patientName),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _metric(
                              _formatQuantity(medication.stockQuantity),
                              _tr('المخزون الحالي', 'Current stock', 'Stock actuel'),
                            ),
                          ),
                          Expanded(
                            child: _metric(
                              days == null
                                  ? '—'
                                  : '${days.toStringAsFixed(1)} ${_tr('يوم', 'days', 'jours')}',
                              _tr('المدة المتوقعة', 'Days remaining', 'Jours restants'),
                            ),
                          ),
                        ],
                      ),
                      if (out || low) ...[
                        const SizedBox(height: 14),
                        Text(
                          out
                              ? _tr('المخزون نافد.', 'Out of stock.', 'Stock épuisé.')
                              : _tr('المخزون منخفض.', 'Low stock.', 'Stock faible.'),
                          style: TextStyle(
                            color: AppColors.danger,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (widget.canManageStock) ...[
                TextField(
                  controller: _quantityController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: _tr('كمية الإضافة', 'Refill quantity', 'Quantité à ajouter'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _refill,
                    icon: const Icon(Icons.add_box_rounded),
                    label: Text(_tr('إضافة إلى المخزون', 'Add to stock', 'Ajouter au stock')),
                  ),
                ),
              ] else
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      _tr(
                        'ليس لديك صلاحية تعديل المخزون.',
                        'You do not have permission to change stock.',
                        'Vous n’avez pas la permission de modifier le stock.',
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

  Widget _metric(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
        const SizedBox(height: 3),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  String _formatQuantity(double value) {
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
}
