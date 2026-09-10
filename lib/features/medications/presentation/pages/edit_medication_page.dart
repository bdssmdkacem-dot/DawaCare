import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../../models/medication.dart';
import '../../../../models/medication_schedule.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../data/medication_repository.dart';
import '../providers/medication_provider.dart';

enum _EditFrequency { daily, timesPerDay, everyHours, specificDays, once, prn }

/// Full medication editor. It rebuilds future schedules instead of editing one schedule.
class EditMedicationPage extends StatefulWidget {
  final Medication medication;
  final List<MedicationSchedule> schedules;

  const EditMedicationPage({super.key, required this.medication, required this.schedules});

  @override
  State<EditMedicationPage> createState() => _EditMedicationPageState();
}

class _EditMedicationPageState extends State<EditMedicationPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _strength = TextEditingController();
  final _dose = TextEditingController(text: '1');
  final _times = TextEditingController(text: '1');
  final _hours = TextEditingController(text: '8');
  final _instructions = TextEditingController();
  final _repo = MedicationRepository();
  final _uuid = const Uuid();

  String? _form;
  String _unit = 'unit';
  _EditFrequency _frequency = _EditFrequency.daily;
  TimeOfDay _time = const TimeOfDay(hour: 8, minute: 0);
  final Set<int> _days = <int>{};
  DateTime _start = DateTime.now();
  DateTime? _end;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final m = widget.medication;
    _name.text = m.name;
    _strength.text = m.strength ?? '';
    _instructions.text = m.instructions ?? '';
    _form = m.dosageForm;
    _unit = m.stockUnit;
    _start = m.startDate;
    _end = m.endDate;
    final active = widget.schedules.where((s) => s.type != ScheduleType.prn).toList();
    if (widget.schedules.any((s) => s.type == ScheduleType.prn)) {
      _frequency = _EditFrequency.prn;
    } else if (active.length > 1) {
      final times = active.map((s) => s.time).toSet();
      _times.text = times.length.toString();
      _frequency = _EditFrequency.timesPerDay;
    } else if (active.length == 1) {
      final s = active.first;
      _frequency = switch (s.type) {
        ScheduleType.once => _EditFrequency.once,
        ScheduleType.specificDays => _EditFrequency.specificDays,
        _ => _EditFrequency.daily,
      };
      _days.addAll(s.daysOfWeek);
    }
    if (active.isNotEmpty) {
      final parts = active.first.time.split(':');
      _time = TimeOfDay(hour: int.tryParse(parts.first) ?? 8, minute: int.tryParse(parts.last) ?? 0);
      _dose.text = active.first.doseAmount;
    }
  }

  @override
  void dispose() {
    _name.dispose(); _strength.dispose(); _dose.dispose(); _times.dispose(); _hours.dispose(); _instructions.dispose();
    super.dispose();
  }

  double? _number(String value) => double.tryParse(value.trim().replaceAll(',', '.'));
  String _timeValue(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  List<TimeOfDay> _buildTimes() {
    if (_frequency == _EditFrequency.timesPerDay) {
      final count = int.tryParse(_times.text) ?? 0;
      if (count < 1 || count > 6) return [];
      final step = 24 / count;
      return List.generate(count, (i) => TimeOfDay(hour: (_time.hour + (i * step).round()) % 24, minute: _time.minute));
    }
    if (_frequency == _EditFrequency.everyHours) {
      final hours = int.tryParse(_hours.text) ?? 0;
      if (hours <= 0 || hours > 24 || 24 % hours != 0) return [];
      return List.generate(24 ~/ hours, (i) => TimeOfDay(hour: (_time.hour + i * hours) % 24, minute: _time.minute));
    }
    return [_time];
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final patientId = auth.profile?.id;
    if (patientId == null) return;
    final dose = _number(_dose.text);
    if (dose == null || dose <= 0) return;
    if (_frequency == _EditFrequency.specificDays && _days.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اختر يومًا واحدًا على الأقل.')));
      return;
    }
    final times = _buildTimes();
    if (times.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تحقق من عدد الجرعات أو الفاصل الزمني.')));
      return;
    }
    setState(() => _saving = true);
    final type = switch (_frequency) {
      _EditFrequency.prn => ScheduleType.prn,
      _EditFrequency.once => ScheduleType.once,
      _EditFrequency.specificDays => ScheduleType.specificDays,
      _ => ScheduleType.daily,
    };
    final timezone = auth.profile?.timezone ?? 'Africa/Casablanca';
    final schedules = <MedicationSchedule>[];
    for (final t in times) {
      schedules.add(MedicationSchedule(
        id: _uuid.v4(), medicationId: widget.medication.id, type: type, time: _timeValue(t),
        daysOfWeek: _frequency == _EditFrequency.specificDays ? (_days.toList()..sort()) : const [],
        intervalDays: null, doseAmount: _dose.text.trim(), startDate: _start, endDate: _end, timezone: timezone,
      ));
    }
    if (_frequency == _EditFrequency.prn) {
      schedules
        ..clear()
        ..add(MedicationSchedule(id: _uuid.v4(), medicationId: widget.medication.id, type: ScheduleType.prn, time: _timeValue(_time), doseAmount: _dose.text.trim(), startDate: _start, endDate: _end, timezone: timezone));
    }

    final updated = Medication(
      id: widget.medication.id, patientId: widget.medication.patientId, name: _name.text.trim(), genericName: widget.medication.genericName,
      strength: _strength.text.trim().isEmpty ? null : _strength.text.trim(), dosageForm: _form, instructions: _instructions.text.trim().isEmpty ? null : _instructions.text.trim(),
      imageUrl: widget.medication.imageUrl, startDate: _start, endDate: _end, active: widget.medication.active, createdBy: widget.medication.createdBy, createdAt: widget.medication.createdAt,
      stockEnabled: widget.medication.stockEnabled, stockQuantity: widget.medication.stockQuantity, stockUnit: _unit, packageQuantity: widget.medication.packageQuantity, lowStockThreshold: widget.medication.lowStockThreshold,
    );

    final ok = await context.read<MedicationProvider>().updateMedicationAndSchedules(medication: updated, schedules: schedules);
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context, true);
    else ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.read<MedicationProvider>().error ?? 'تعذر حفظ التعديل.')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تعديل الدواء')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'اسم الدواء'), validator: (v) => v == null || v.trim().isEmpty ? 'أدخل اسم الدواء' : null),
            const SizedBox(height: 12),
            TextFormField(controller: _strength, decoration: const InputDecoration(labelText: 'التركيز (مثلاً 500 mg)')),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(value: _form, decoration: const InputDecoration(labelText: 'شكل الدواء'), items: const ['قرص','كبسولة','شراب','قطرة','حقنة','كريم/مرهم','بخاخ','أخرى'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: (v) => setState(() { _form = v; _unit = {'قرص':'tablet','كبسولة':'capsule','شراب':'ml','قطرة':'drop','حقنة':'injection'}[v] ?? 'unit'; })),
            const SizedBox(height: 20),
            const Text('طريقة الجرعة', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            DropdownButtonFormField<_EditFrequency>(value: _frequency, items: const [
              DropdownMenuItem(value: _EditFrequency.daily, child: Text('مرة يوميًا')),
              DropdownMenuItem(value: _EditFrequency.timesPerDay, child: Text('عدة مرات يوميًا')),
              DropdownMenuItem(value: _EditFrequency.everyHours, child: Text('كل X ساعات')),
              DropdownMenuItem(value: _EditFrequency.specificDays, child: Text('أيام محددة')),
              DropdownMenuItem(value: _EditFrequency.once, child: Text('مرة واحدة')),
              DropdownMenuItem(value: _EditFrequency.prn, child: Text('عند الحاجة PRN')),
            ], onChanged: (v) => setState(() => _frequency = v ?? _EditFrequency.daily)),
            const SizedBox(height: 12),
            TextFormField(controller: _dose, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'الكمية في الجرعة', suffixText: _unit == 'ml' ? 'مل' : _unit == 'drop' ? 'قطرة' : 'وحدة'), validator: (v) => _number(v ?? '') == null ? 'أدخل كمية صحيحة' : null),
            if (_frequency == _EditFrequency.timesPerDay) ...[
              const SizedBox(height: 12),
              TextFormField(controller: _times, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'عدد المرات يوميًا')),
            ],
            if (_frequency == _EditFrequency.everyHours) ...[
              const SizedBox(height: 12),
              TextFormField(controller: _hours, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'كل كم ساعة؟')),
            ],
            if (_frequency != _EditFrequency.prn) ...[
              const SizedBox(height: 12),
              ListTile(leading: const Icon(Icons.schedule_rounded), title: Text('وقت البداية: ${_timeValue(_time)}'), trailing: const Icon(Icons.chevron_right), onTap: () async { final t = await showTimePicker(context: context, initialTime: _time); if (t != null) setState(() => _time = t); }),
            ],
            if (_frequency == _EditFrequency.specificDays) ...[
              const SizedBox(height: 8),
              Wrap(spacing: 6, children: List.generate(7, (i) { final day = i + 1; const labels = ['الأحد','الاثنين','الثلاثاء','الأربعاء','الخميس','الجمعة','السبت']; return FilterChip(label: Text(labels[i]), selected: _days.contains(day), onSelected: (v) => setState(() => v ? _days.add(day) : _days.remove(day))); })),
            ],
            const SizedBox(height: 12),
            TextFormField(controller: _instructions, maxLines: 3, decoration: const InputDecoration(labelText: 'تعليمات إضافية')),
            const SizedBox(height: 24),
            FilledButton.icon(onPressed: _saving ? null : _save, icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_rounded), label: Text(_saving ? 'جاري الحفظ...' : 'حفظ التعديلات')),
          ],
        ),
      ),
    );
  }
}
