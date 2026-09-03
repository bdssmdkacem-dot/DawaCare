import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
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
    if (file == null) {
      return;
    }
    final bytes = await file.readAsBytes();
    if (!mounted) {
      return;
    }
    setState(() => _imageBytes = bytes);
  }

  Future<void> _chooseImageSource() async {
    final l = AppLocalizations.of(context);
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: Text(l.cameraMedicine),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: Text(l.galleryMedicine),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source != null) {
      await _pickImage(source);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
    );
    if (picked != null && mounted) {
      setState(() => _time = picked);
    }
  }

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : (_endDate ?? _startDate),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() => isStart ? _startDate = picked : _endDate = picked);
  }

  Future<void> _submit() async {
    final l = AppLocalizations.of(context);
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_scheduleType == ScheduleType.specificDays && _selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.chooseAtLeastOneDay)),
      );
      return;
    }
    final auth = context.read<AuthProvider>();
    final userId = auth.profile?.id;
    if (userId == null) {
      return;
    }

    setState(() => _submitting = true);
    const uuid = Uuid();
    final time =
        '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}';
    final medication = Medication(
      id: uuid.v4(),
      patientId: userId,
      name: _nameCtrl.text.trim(),
      strength: _strengthCtrl.text.trim().isEmpty
          ? null
          : _strengthCtrl.text.trim(),
      dosageForm: _dosageForm,
      instructions: _instructionsCtrl.text.trim().isEmpty
          ? null
          : _instructionsCtrl.text.trim(),
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
      doseAmount:
          _doseAmountCtrl.text.trim().isEmpty ? '1' : _doseAmountCtrl.text.trim(),
      startDate: _startDate,
      endDate: _endDate,
      timezone: auth.profile?.timezone ?? 'Africa/Casablanca',
    );

    final ok = await context.read<MedicationProvider>().addMedication(
          medication: medication,
          schedule: schedule,
          imageBytes: _imageBytes,
        );
    if (!mounted) {
      return;
    }
    setState(() => _submitting = false);
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.read<MedicationProvider>().error ?? l.unexpectedError,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.newMedicine)),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            children: [
              _MedicationImagePicker(
                bytes: _imageBytes,
                onTap: _chooseImageSource,
                onRemove: _imageBytes == null
                    ? null
                    : () => setState(() => _imageBytes = null),
              ),
              const SizedBox(height: 24),
              _sectionHeader(context, Icons.medication_rounded, l.medicineName),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                  labelText: l.medicineName,
                  prefixIcon: const Icon(Icons.medication_rounded),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? l.enterMedicineName : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _strengthCtrl,
                      decoration: InputDecoration(
                        labelText: l.strength,
                        prefixIcon: const Icon(Icons.science_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _dosageForm,
                      decoration: InputDecoration(
                        labelText: l.dosageForm,
                        prefixIcon: const Icon(Icons.category_rounded),
                      ),
                      items: _dosageForms
                          .map(
                            (f) => DropdownMenuItem(
                              value: f,
                              child: Text(l.dosageFormLabel(f)),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _dosageForm = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _doseAmountCtrl,
                decoration: InputDecoration(
                  labelText: l.doseAmount,
                  prefixIcon: const Icon(Icons.exposure_plus_1_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _instructionsCtrl,
                decoration: InputDecoration(
                  labelText: l.instructionsOptional,
                  prefixIcon: const Icon(Icons.notes_rounded),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 28),
              _sectionHeader(context, Icons.repeat_rounded, l.frequency),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _typeChip(l.daily, ScheduleType.daily),
                  _typeChip(l.specificDays, ScheduleType.specificDays),
                  _typeChip(l.everyFewDays, ScheduleType.interval),
                  _typeChip(l.once, ScheduleType.once),
                  _typeChip(l.asNeeded, ScheduleType.prn),
                ],
              ),
              if (_scheduleType == ScheduleType.specificDays) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(7, (i) {
                    final day = i + 1;
                    return FilterChip(
                      label: Text(l.weekdayLabel(day)),
                      selected: _selectedDays.contains(day),
                      onSelected: (v) => setState(
                        () => v
                            ? _selectedDays.add(day)
                            : _selectedDays.remove(day),
                      ),
                    );
                  }),
                ),
              ],
              if (_scheduleType == ScheduleType.interval) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _intervalCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l.everyHowManyDays,
                    prefixIcon: const Icon(Icons.calendar_view_day_rounded),
                  ),
                ),
              ],
              if (_scheduleType != ScheduleType.prn) ...[
                const SizedBox(height: 16),
                _settingsTile(
                  context,
                  icon: Icons.access_time_rounded,
                  title: l.doseTime,
                  value: _time.format(context),
                  onTap: _pickTime,
                ),
              ],
              const SizedBox(height: 8),
              const Divider(height: 32),
              _sectionHeader(context, Icons.event_rounded, l.startDate),
              const SizedBox(height: 8),
              _settingsTile(
                context,
                icon: Icons.event_available_rounded,
                title: l.startDate,
                value: DateTimeUtils.formatShortDate(_startDate),
                onTap: () => _pickDate(isStart: true),
              ),
              _settingsTile(
                context,
                icon: Icons.event_busy_rounded,
                title: l.endDateOptional,
                value: _endDate != null
                    ? DateTimeUtils.formatShortDate(_endDate!)
                    : '—',
                onTap: () => _pickDate(isStart: false),
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: l.saveMedicine,
                onPressed: _submit,
                loading: _submitting,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, IconData icon, String title) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: .10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.primary, size: 21),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
      ],
    );
  }

  Widget _settingsTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
        onTap: onTap,
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

  const _MedicationImagePicker({
    required this.bytes,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: theme.colorScheme.outlineVariant),
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: .45),
        ),
        clipBehavior: Clip.antiAlias,
        child: bytes == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: .10),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.add_a_photo_rounded,
                      size: 34,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l.addMedicinePhoto,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(l.addMedicinePhotoHint),
                ],
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  Image.memory(bytes!, fit: BoxFit.cover),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Row(
                      children: [
                        IconButton.filledTonal(
                          onPressed: onTap,
                          icon: const Icon(Icons.edit_rounded),
                        ),
                        if (onRemove != null) ...[
                          const SizedBox(width: 6),
                          IconButton.filledTonal(
                            onPressed: onRemove,
                            icon: const Icon(Icons.delete_outline_rounded),
                          ),
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
