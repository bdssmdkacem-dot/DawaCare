import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/medication_provider.dart';

class MedicationStockHistory extends StatefulWidget {
  final String medicationId;
  final String unit;

  const MedicationStockHistory({super.key, required this.medicationId, required this.unit});

  @override
  State<MedicationStockHistory> createState() => MedicationStockHistoryState();
}

class MedicationStockHistoryState extends State<MedicationStockHistory> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<MedicationProvider>().fetchStockTransactions(widget.medicationId);
  }

  void refresh() {
    if (!mounted) return;
    setState(() {
      _future = context.read<MedicationProvider>().fetchStockTransactions(widget.medicationId);
    });
  }

  String _typeLabel(String? type) {
    switch (type) {
      case 'INITIAL':
        return 'رصيد ابتدائي';
      case 'ADD':
        return 'إضافة مخزون';
      case 'TAKEN':
        return 'استهلاك جرعة';
      case 'ADJUSTMENT':
        return 'تعديل المخزون';
      default:
        return type ?? 'حركة مخزون';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(child: Text('سجل المخزون', style: TextStyle(fontWeight: FontWeight.bold))),
                IconButton(onPressed: refresh, icon: const Icon(Icons.refresh)),
              ],
            ),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()));
                }
                if (snapshot.hasError) {
                  return const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('تعذّر تحميل سجل المخزون.'));
                }
                final rows = snapshot.data ?? const <Map<String, dynamic>>[];
                if (rows.isEmpty) {
                  return const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('لا توجد حركات مخزون بعد.'));
                }
                return Column(
                  children: rows.map((row) {
                    final quantity = (row['quantity'] as num?)?.toDouble() ?? 0;
                    final createdAt = DateTime.tryParse(row['created_at']?.toString() ?? '');
                    final date = createdAt == null ? '' : DateFormat('dd/MM/yyyy HH:mm').format(createdAt.toLocal());
                    final note = row['note']?.toString();
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(child: Icon(quantity < 0 ? Icons.remove : Icons.add)),
                      title: Text(_typeLabel(row['transaction_type']?.toString())),
                      subtitle: Text(note?.isNotEmpty == true ? '$date\n$note' : date),
                      isThreeLine: note?.isNotEmpty == true,
                      trailing: Text('${quantity > 0 ? '+' : ''}${quantity.toStringAsFixed(quantity == quantity.roundToDouble() ? 0 : 2)} ${widget.unit}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
