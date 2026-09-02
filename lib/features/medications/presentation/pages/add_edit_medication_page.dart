import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/utils/date_time_utils.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../models/medication.dart';
import '../../../../models/medication_schedule.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/medication_provider.dart';

const _dosageForms = ['قرص', 'كبسولة', 'شراب', 'حقنة', 'قطرة', 'أخرى'];

class AddMedicationPage extends StatefulWidget {
  const AddMedicationPage({super.key});

  @override
  State<AddMedicationPage> createState() => _AddMedicationPageState();
}

class _AddMedicationPageState extends State<AddMedicationPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _strengthCtrl = TextEditingController();
  final _instructionsCtrl = TextEditingController();
  final _doseAmountCtrl = TextEditingController(text: '1');
  final _intervalCtrl = TextEditingController(text: '2');
  final _imagePicker = ImagePicker();

  Uint8List? _imageBytes;
  String? _dosageForm;
  ScheduleType _scheduleType = ScheduleType.daily;
  TimeOfDay _time = const TimeOfDay(hour: 8, minute: 0);
  final Set<int> _selectedDays = {};
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  bool _submitting = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _strengthCtrl.dispose();
    _instructionsCtrl.dispose();
    _doseAmountCtrl.dispose();
    _intervalCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final file = await _imagePicker.pickImage(
      source: source,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 82,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() => _imageBytes = bytes);
  }

  Future<void> _chooseImageSource() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('تصوير الدواء بالكاميرا'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('اختيار صورة من الهاتف'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source != null) await _pickImage(source);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : (_endDate ?? _startDate),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
      } else {
        _endDate = picked;
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_scheduleType == ScheduleType.specificDays && _selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اختر يومًا واحدًا على الأقل')));
      return;
    }

    final auth = context.read<AuthProvider>();
    final userId = auth.profile?.id;
    if (userId == null) return;

    setState(() => _submitting = true);
    const uuid = Uuid();
    final time = '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}';

    final medication = Medication(
      id: uuid.v4(),
      patientId: userId,
      name: _nameCtrl.text.trim(),
      strength: _strengthCtrl.text.trim().isEmpty ? null : _strengthCtrl.text.trim(),
      dosageForm: _dosageForm,
      instructions: _instructionsCtrl.text.trim().isEmpty ? null : _instructionsCtrl.text.trim(),
      imageUrl: null,
      startDate: _startDate,
      endDate: _endDate,
      active: true,
      createdBy: userId,
      createdAt: DateTime.now(),
    );

    final schedule = MedicationSchedule(
      id: uuid.v4(),
      medicationId: medication.id,
      type: _scheduleType,
      time: time,
      daysOfWeek: _scheduleType == ScheduleType.specificDays
          ? (_selectedDays.toList()..sort())
          : const [],
      intervalDays: _scheduleType == ScheduleType.interval
          ? int.tryParse(_intervalCtrl.text) ?? 2
          : null,
      doseAmount: _doseAmountCtrl.text.trim().isEmpty ? '1' : _doseAmountCtrl.text.trim(),
      startDate: _startDate,
      endDate: _endDate,
      timezone: auth.profile?.timezone ?? 'Africa/Casablanca',
    );

    final ok = await context.read<MedicationProvider>().addMedication(
          medication: medication,
          schedule: schedule,
          imageBytes: _imageBytes,
        );
    if (!mounted) return;
    setState(() => _submitting = false);

    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.read<MedicationProvider>().error ?? 'حدث خطأ')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('دواء جديد')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _MedicationImagePicker(
                bytes: _imageBytes,
                onTap: _chooseImageSource,
                onRemove: _imageBytes == null ? null : () => setState(() => _imageBytes = null),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'اسم الدواء *'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'أدخل اسم الدواء' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _strengthCtrl,
                      decoration: const InputDecoration(labelText: 'التركيز (مثال: 500 ملغ)'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _dosageForm,
                      decoration: const InputDecoration(labelText: 'الشكل'),
                      items: _dosageForms.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                      onChanged: (v) => setState(() => _dosageForm = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _doseAmountCtrl,
                decoration: const InputDecoration(labelText: 'الكمية في كل جرعة (مثال: قرص واحد)'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _instructionsCtrl,
                decoration: const InputDecoration(labelText: 'تعليمات (اختياري)'),
                maxLines: 2,
              ),
              const SizedBox(height: 24),
              Text('التكرار', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _typeChip('يوميًا', ScheduleType.daily),
                  _typeChip('أيام محددة', ScheduleType.specificDays),
                  _typeChip('كل عدة أيام', ScheduleType.interval),
                  _typeChip('مرة واحدة', ScheduleType.once),
                  _typeChip('عند الحاجة', ScheduleType.prn),
                ],
              ),
              if (_scheduleType == ScheduleType.specificDays) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(7, (i) {
                    final day = i + 1;
                    final selected = _selectedDays.contains(day);
                    return FilterChip(
                      label: Text(DateTimeUtils.appWeekdayNamesAr[day]),
                      selected: selected,
                      onSelected: (v) => setState(() => v ? _selectedDays.add(day) : _selectedDays.remove(day)),
                    );
                  }),
                ),
              ],
              if (_scheduleType == ScheduleType.interval) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _intervalCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'كل كم يوم؟'),
                ),
              ],
              if (_scheduleType != ScheduleType.prn) ...[
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('وقت الجرعة'),
                  trailing: Text(_time.format(context), style: const TextStyle(fontWeight: FontWeight.w700)),
                  onTap: _pickTime,
                ),
              ],
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('تاريخ البدء'),
                trailing: Text(DateTimeUtils.formatShortDate(_startDate)),
                onTap: () => _pickDate(isStart: true),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('تاريخ الانتهاء (اختياري)'),
                trailing: Text(_endDate != null ? DateTimeUtils.formatShortDate(_endDate!) : '—'),
                onTap: () => _pickDate(isStart: false),
              ),
              const SizedBox(height: 24),
              PrimaryButton(label: 'حفظ الدواء', onPressed: _submit, loading: _submitting),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _typeChip(String label, ScheduleType type) {
    return ChoiceChip(
      label: Text(label),
      selected: _scheduleType == type,
      onSelected: (_) => setState(() => _scheduleType = type),
    );
  }
}

class _MedicationImagePicker extends StatelessWidget {
  final Uint8List? bytes;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  const _MedicationImagePicker({required this.bytes, required this.onTap, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        height: 190,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.colorScheme.outlineVariant),
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        ),
        clipBehavior: Clip.antiAlias,
        child: bytes == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo_rounded, size: 52, color: theme.colorScheme.primary),
                  const SizedBox(height: 10),
                  const Text('أضف صورة الدواء', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  const Text('صوّر العلبة لتسهيل التعرّف على الدواء'),
                ],
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  Image.memory(bytes!, fit: BoxFit.cover),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Row(
                      children: [
                        IconButton.filledTonal(onPressed: onTap, icon: const Icon(Icons.edit_rounded)),
                        if (onRemove != null) ...[
                          const SizedBox(width: 6),
                          IconButton.filledTonal(onPressed: onRemove, icon: const Icon(Icons.delete_outline_rounded)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
