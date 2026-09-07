import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/notifications/notification_service.dart';
import '../../../models/medication.dart';

class StockAlertService {
  StockAlertService._();
  static final StockAlertService instance = StockAlertService._();

  static const _statePrefix = 'dawacare_stock_alert_state_';

  Future<void> checkMedication(Medication medication) async {
    if (!medication.stockEnabled) return;

    final state = _stateFor(medication);
    if (state == null) return;

    final prefs = await SharedPreferences.getInstance();
    final key = '$_statePrefix${medication.id}';
    final previous = prefs.getString(key);
    if (previous == state) return;

    await prefs.setString(key, state);

    final unit = medication.stockUnit;
    if (state == 'DEPLETED') {
      await NotificationService.instance.showCaregiverAlert(
        title: 'المخزون نفد ⚠️',
        body: '${medication.name}: لا توجد كمية متبقية ($unit).',
        payload: 'STOCK_ALERT:${medication.id}:DEPLETED',
      );
    } else if (state == 'LOW') {
      await NotificationService.instance.showCaregiverAlert(
        title: 'المخزون منخفض ⚠️',
        body: '${medication.name}: المتبقي ${_format(medication.stockQuantity)} $unit، والحد ${_format(medication.lowStockThreshold)} $unit.',
        payload: 'STOCK_ALERT:${medication.id}:LOW',
      );
    }
  }

  String? _stateFor(Medication medication) {
    if (medication.stockQuantity <= 0) return 'DEPLETED';
    if (medication.stockQuantity <= medication.lowStockThreshold) return 'LOW';
    return 'OK';
  }

  String _format(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
}
