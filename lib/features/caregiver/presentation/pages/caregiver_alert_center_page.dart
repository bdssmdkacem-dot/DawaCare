import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../models/caregiver_alert.dart';
import '../../../../models/caregiver_link.dart';
import '../../../../models/medication.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../medications/presentation/providers/medication_provider.dart';
import '../providers/caregiver_provider.dart';
import 'caregiver_medication_detail_page.dart';
import 'patient_detail_page.dart';

class CaregiverAlertCenterPage extends StatelessWidget {
  const CaregiverAlertCenterPage({super.key});

  Future<void> _openAlert(BuildContext context, CaregiverAlert alert) async {
    final caregiver = context.read<CaregiverProvider>();
    await caregiver.markAlertRead(alert);
    if (!context.mounted) return;

    final link = caregiver.linkedPatients.cast<CaregiverLink?>().firstWhere(
      (item) => item?.patientId == alert.patientId,
      orElse: () => null,
    );
    if (link == null) return;

    // Stock alerts may carry medication_id. Older alerts can still be resolved
    // safely by matching the medication name contained in their message.
    final isStock = _kind(alert) == _AlertKind.lowStock || _kind(alert) == _AlertKind.outOfStock;
    if (isStock) {
      final medications = MedicationProvider();
      try {
        await medications.load(alert.patientId);
        Medication? target;
        if (alert.medicationId != null) {
          for (final medication in medications.medications) {
            if (medication.id == alert.medicationId) {
              target = medication;
              break;
            }
          }
        }
        target ??= _matchMedication(medications.medications, alert.message);
        if (!context.mounted) return;
        if (target != null) {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CaregiverMedicationDetailPage(
                medication: target!,
                patientName: link.patientName,
                canManageDoses: PatientPermissionsForAlert.canManage(link.role),
              ),
            ),
          );
          return;
        }
      } finally {
        medications.dispose();
      }
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PatientDetailPage(
          link: link,
          initialDoseId: alert.doseId,
        ),
      ),
    );
  }

  Medication? _matchMedication(List<Medication> medications, String message) {
    final normalized = message.trim().toLowerCase();
    for (final medication in medications) {
      final name = medication.name.trim().toLowerCase();
      if (name.isNotEmpty && normalized.contains(name)) return medication;
    }
    return null;
  }

  Future<void> _refresh(BuildContext context) async {
    final userId = context.read<AuthProvider>().profile?.id;
    if (userId != null) await context.read<CaregiverProvider>().load(userId);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final provider = context.watch<CaregiverProvider>();
    final missed = provider.alerts.where((a) => _kind(a) == _AlertKind.missed).toList();
    final low = provider.alerts.where((a) => _kind(a) == _AlertKind.lowStock).toList();
    final out = provider.alerts.where((a) => _kind(a) == _AlertKind.outOfStock).toList();
    final other = provider.alerts.where((a) => _kind(a) == _AlertKind.other).toList();

    return Scaffold(
      appBar: AppBar(title: Text(_tr(context, 'مركز التنبيهات والرعاية', 'Care & Alerts', 'Centre des alertes'))),
      body: RefreshIndicator(
        onRefresh: () => _refresh(context),
        child: provider.isLoading && provider.alerts.isEmpty
            ? const LoadingIndicator()
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
                children: [
                  _summary(context, provider),
                  const SizedBox(height: 18),
                  _section(context, l, _AlertKind.missed, missed),
                  _section(context, l, _AlertKind.lowStock, low),
                  _section(context, l, _AlertKind.outOfStock, out),
                  if (other.isNotEmpty) _section(context, l, _AlertKind.other, other),
                  if (provider.alerts.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          children: [
                            Icon(Icons.notifications_off_rounded, size: 48, color: AppColors.primary.withValues(alpha: .65)),
                            const SizedBox(height: 12),
                            Text(_tr(context, 'لا توجد تنبيهات تحتاج إلى تدخل الآن.', 'No alerts need your attention right now.', 'Aucune alerte ne nécessite votre intervention.'), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _summary(BuildContext context, CaregiverProvider provider) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        _metric(context, Icons.warning_amber_rounded, '${provider.unreadAlertCount}', _tr(context, 'غير مقروء', 'Unread', 'Non lues')),
        _divider(),
        _metric(context, Icons.medication_rounded, '${provider.lowStockMedicationCount}', _tr(context, 'مخزون منخفض', 'Low stock', 'Stock faible')),
        _divider(),
        _metric(context, Icons.inventory_2_rounded, '${provider.outOfStockMedicationCount}', _tr(context, 'نفد المخزون', 'Out of stock', 'Rupture')),
      ]),
    ),
  );

  Widget _metric(BuildContext context, IconData icon, String value, String label) => Expanded(child: Column(children: [Icon(icon, color: AppColors.primary, size: 22), const SizedBox(height: 5), Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)), const SizedBox(height: 2), Text(label, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall)]));

  Widget _divider() => Container(width: 1, height: 48, margin: const EdgeInsets.symmetric(horizontal: 8), color: Colors.grey.withValues(alpha: .18));

  Widget _section(BuildContext context, AppLocalizations l, _AlertKind kind, List<CaregiverAlert> alerts) {
    if (alerts.isEmpty) return const SizedBox.shrink();
    final title = switch (kind) {
      _AlertKind.missed => _tr(context, 'جرعات فائتة', 'Missed doses', 'Doses manquées'),
      _AlertKind.lowStock => _tr(context, 'مخزون منخفض', 'Low stock', 'Stock faible'),
      _AlertKind.outOfStock => _tr(context, 'نفاد المخزون', 'Out of stock', 'Rupture de stock'),
      _AlertKind.other => l.alerts,
    };
    final icon = switch (kind) {
      _AlertKind.missed => Icons.schedule_rounded,
      _AlertKind.lowStock => Icons.inventory_rounded,
      _AlertKind.outOfStock => Icons.production_quantity_limits_rounded,
      _AlertKind.other => Icons.notifications_rounded,
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.only(bottom: 9), child: Row(children: [Icon(icon, color: AppColors.primary, size: 21), const SizedBox(width: 8), Expanded(child: Text('$title (${alerts.length})', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)))])),
      ...alerts.map((alert) => _alertTile(context, alert)),
      const SizedBox(height: 16),
    ]);
  }

  Widget _alertTile(BuildContext context, CaregiverAlert alert) {
    final kind = _kind(alert);
    final icon = switch (kind) {
      _AlertKind.missed => Icons.schedule_rounded,
      _AlertKind.lowStock => Icons.inventory_rounded,
      _AlertKind.outOfStock => Icons.production_quantity_limits_rounded,
      _AlertKind.other => Icons.notifications_rounded,
    };
    final title = switch (kind) {
      _AlertKind.missed => _tr(context, 'جرعة فائتة', 'Missed dose', 'Dose manquée'),
      _AlertKind.lowStock => _tr(context, 'المخزون منخفض', 'Low stock', 'Stock faible'),
      _AlertKind.outOfStock => _tr(context, 'المخزون نفد', 'Out of stock', 'Rupture de stock'),
      _AlertKind.other => alert.type,
    };
    final stock = kind == _AlertKind.lowStock || kind == _AlertKind.outOfStock;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openAlert(context, alert),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Row(children: [
            Container(width: 46, height: 46, decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: .10), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: AppColors.primary)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900))), if (!alert.read) Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.primary))]),
              const SizedBox(height: 3),
              Text(alert.patientName, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(alert.message, maxLines: 2, overflow: TextOverflow.ellipsis),
              if (stock) ...[
                const SizedBox(height: 7),
                Row(children: [Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.primary), const SizedBox(width: 5), Text(_tr(context, 'فتح الدواء وإدارة المخزون', 'Open medication & manage stock', 'Ouvrir le médicament et gérer le stock'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800))]),
              ],
            ])),
            const Icon(Icons.chevron_right_rounded),
          ]),
        ),
      ),
    );
  }

  static _AlertKind _kind(CaregiverAlert alert) {
    final value = '${alert.type} ${alert.message}'.toUpperCase();
    if (value.contains('OUT_OF_STOCK') || value.contains('OUT OF STOCK') || value.contains('DEPLETED') || value.contains('نفد') || value.contains('نفاذ')) return _AlertKind.outOfStock;
    if (value.contains('LOW_STOCK') || value.contains('LOW STOCK') || value.contains('LOW') || value.contains('منخفض')) return _AlertKind.lowStock;
    if (value.contains('MISSED') || value.contains('MISS') || value.contains('فائت') || value.contains('فائتة')) return _AlertKind.missed;
    return _AlertKind.other;
  }

  String _tr(BuildContext context, String ar, String en, String fr) {
    switch (Localizations.localeOf(context).languageCode) { case 'en': return en; case 'fr': return fr; default: return ar; }
  }
}

enum _AlertKind { missed, lowStock, outOfStock, other }

class PatientPermissionsForAlert {
  static bool canManage(CaregiverRole role) => role != CaregiverRole.viewer;
}
