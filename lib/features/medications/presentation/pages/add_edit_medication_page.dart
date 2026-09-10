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
import '../../data/medication_schedule_service.dart';
import '../providers/medication_provider.dart';

const _forms = <String>[
  'قرص',
  'كبسولة',
  'شراب',
  'قطرة',
  'حقنة',
  'كريم/مرهم',
  'بخاخ',
  'أخرى',
];

const _units = <String, String>{
  'قرص': 'tablet',
  'كبسولة': 'capsule',
  'شراب': 'ml',
  'قطرة': 'drop',
  'حقنة': 'injection',
  'كريم/مرهم': 'unit',
  'بخاخ': 'unit',
  'أخرى': 'unit',
};

enum _Frequency { daily, timesPerDay, everyHours, specificDays, once, prn }

class AddMedicationPage extends StatefulWidget {
  const AddMedicationPage({super.key});

  @override
  State<AddMedicationPage> createState() => _AddMedicationPageState();
}

class _AddMedicationPageState extends State<AddMedicationPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _strength = TextEditingController();
  final _dose = TextEditingController(text: '1');
  final _times = TextEditingController(text: '2');
  final _hours = TextEditingController(text: '8');
  final _stock = TextEditingController(text: '0');
  final _pack = TextEditingController();
  final _threshold = TextEditingController(text: '5');
  final _instructions = TextEditingController();

  final _picker = ImagePicker();
  final _scheduleService = MedicationScheduleService();

  Uint8List? _image;
  String? _form;
  String _unit = 'unit';
  bool _stockEnabled = false;
  bool _submitting = false;
  _Frequency _frequency = _Frequency.daily;
  TimeOfDay _time = const TimeOfDay(hour: 8, minute: 0);
  final Set<int> _days = <int>{};
  DateTime _start = DateTime.now();
  DateTime? _end;

  @override
  void dispose() {
    for (final controller in [
      _name,
      _strength,
      _dose,
      _times,
      _hours,
      _stock,
      _pack,
      _threshold,
      _instructions,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  double? _number(String value) =>
      double.tryParse(value.trim().replaceAll(',', '.'));

  String _timeValue(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  String _unitLabel(String unit) => <String, String>{
        'tablet': 'قرص',
        'capsule': 'كبسولة',
        'ml': 'مل',
        'drop': 'قطرة',
        'injection': 'حقنة',
        'unit': 'وحدة',
      }[unit] ?? 'وحدة';

  String _formHint() {
    switch (_form) {
      case 'قرص':
      case 'كبسولة':
        return 'مثال: 1 ${_unitLabel(_unit)} في كل جرعة';
      case 'شراب':
        return 'مثال: 5 مل في كل جرعة';
      case 'قطرة':
        return 'مثال: 2 قطرة في كل جرعة';
      case 'حقنة':
        return 'مثال: 1 حقنة في كل جرعة';
      case 'كريم/مرهم':
        return 'مثال: كمية مناسبة في كل استعمال';
      case 'بخاخ':
        return 'مثال: 2 بخة في كل استعمال';
      default:
        return 'أدخل الكمية في كل جرعة';
    }
  }

  String _frequencyHint() {
    switch (_frequency) {
      case _Frequency.daily:
        return 'جرعة واحدة يوميًا في الوقت الذي تختاره.';
      case _Frequency.timesPerDay:
        return 'سيتم توزيع الجرعات تلقائيًا على اليوم بدءًا من الوقت المحدد.';
      case _Frequency.everyHours:
        return 'الفاصل يجب أن يقسم 24 ساعة، مثل 4 أو 6 أو 8 أو 12.';
      case _Frequency.specificDays:
        return 'اختر الأيام التي يجب أن تظهر فيها الجرعة.';
      case _Frequency.once:
        return 'هذه الجرعة تُنشأ مرة واحدة فقط.';
      case _Frequency.prn:
        return 'للأدوية عند الحاجة. سجّل الاستعمال يدويًا عند أخذ الجرعة.';
    }
  }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: Text(AppLocalizations.of(context).cameraMedicine),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: Text(AppLocalizations.of(context).galleryMedicine),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;
    final file = await _picker.pickImage(
      source: source,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 82,
    );
    if (file == null) return;

    final bytes = await file.readAsBytes();
    if (mounted) setState(() => _image = bytes);
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(context: context, initialTime: _time);
    if (time != null && mounted) setState(() => _time = time);
  }

  Future<void> _pickDate(bool start) async {
    final date = await showDatePicker(
      context: context,
      initialDate: start ? _start : (_end ?? _start),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 1095)),
    );
    if (date == null || !mounted) return;

    setState(() {
      if (start) {
        _start = date;
        if (_end != null && _end!.isBefore(date)) _end = null;
      } else {
        _end = date;
      }
    });
  }

  List<TimeOfDay> _buildTimes() {
    if (_frequency == _Frequency.timesPerDay) {
      final count = int.tryParse(_times.text) ?? 0;
      if (count < 1 || count > 6) return const [];
      final step = 24 / count;
      return List.generate(
        count,
        (index) => TimeOfDay(
          hour: (_time.hour + (index * step).round()) % 24,
          minute: _time.minute,
        ),
      );
    }

    if (_frequency == _Frequency.everyHours) {
      final hours = int.tryParse(_hours.text) ?? 0;
      if (hours <= 0 || hours > 24 || 24 % hours != 0) return const [];
      return List.generate(
        24 ~/ hours,
        (index) => TimeOfDay(
          hour: (_time.hour + index * hours) % 24,
          minute: _time.minute,
        ),
      );
    }

    return [_time];
  }

  String? _validatePositive(String? value, String label) {
    final number = _number(value ?? '');
    if (number == null || number <= 0) return '$label يجب أن يكون أكبر من صفر';
    return null;
  }

  Future<void> _submit() async {
    final localizations = AppLocalizations.of(context);
    if (!_formKey.currentState!.validate()) return;

    if (_form == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر شكل الدواء أولًا.')),
      );
      return;
    }

    if (_frequency == _Frequency.specificDays && _days.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizations.chooseAtLeastOneDay)),
      );
      return;
    }

    if (_frequency == _Frequency.timesPerDay) {
      final count = int.tryParse(_times.text) ?? 0;
      if (count < 1 || count > 6) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('عدد المرات يجب أن يكون بين 1 و6.')),
        );
        return;
      }
    }

    if (_frequency == _Frequency.everyHours) {
      final hours = int.tryParse(_hours.text) ?? 0;
      if (hours <= 0 || hours > 24 || 24 % hours != 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('الفاصل يجب أن يقسم 24، مثل 4 أو 6 أو 8 أو 12.'),
          ),
        );
        return;
      }
    }

    if (_end != null && _end!.isBefore(_start)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تاريخ الانتهاء يجب أن يكون بعد البداية.')),
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    final patientId = auth.profile?.id;
    if (patientId == null) return;

    final dose = _number(_dose.text);
    if (dose == null || dose <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الجرعة يجب أن تكون أكبر من صفر.')),
      );
      return;
    }

    final stock = _number(_stock.text) ?? 0;
    final pack = _pack.text.trim().isEmpty ? null : _number(_pack.text);
    final threshold = _number(_threshold.text) ?? 5;
    if (_stockEnabled &&
        (stock < 0 || (pack != null && pack <= 0) || threshold < 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تحقق من قيم المخزون.')),
      );
      return;
    }

    final times = _buildTimes();
    if (times.isEmpty) return;

    setState(() => _submitting = true);

    const uuid = Uuid();
    final medicationId = uuid.v4();
    final medication = Medication(
      id: medicationId,
      patientId: patientId,
      name: _name.text.trim(),
      strength: _strength.text.trim().isEmpty ? null : _strength.text.trim(),
      dosageForm: _form,
      instructions: _instructions.text.trim().isEmpty
          ? null
          : _instructions.text.trim(),
      imageUrl: null,
      startDate: _start,
      endDate: _end,
      active: true,
      createdBy: patientId,
      createdAt: DateTime.now(),
      stockEnabled: _stockEnabled,
      stockQuantity: _stockEnabled ? stock : 0,
      stockUnit: _unit,
      packageQuantity: _stockEnabled ? pack : null,
      lowStockThreshold: _stockEnabled ? threshold : 5,
    );

    final type = _frequency == _Frequency.prn
        ? ScheduleType.prn
        : _frequency == _Frequency.once
            ? ScheduleType.once
            : _frequency == _Frequency.specificDays
                ? ScheduleType.specificDays
                : ScheduleType.daily;

    final timezone = auth.profile?.timezone ?? 'Africa/Casablanca';
    final base = MedicationSchedule(
      id: uuid.v4(),
      medicationId: medicationId,
      type: type,
      time: _timeValue(times.first),
      daysOfWeek: _frequency == _Frequency.specificDays
          ? (_days.toList()..sort())
          : const [],
      intervalDays: null,
      doseAmount: _dose.text.trim(),
      startDate: _start,
      endDate: _end,
      timezone: timezone,
    );

    final ok = await context.read<MedicationProvider>().addMedication(
          medication: medication,
          schedule: base,
          imageBytes: _image,
        );

    if (ok && times.length > 1) {
      final extras = times.skip(1).map((time) {
        return MedicationSchedule(
          id: uuid.v4(),
          medicationId: medicationId,
          type: ScheduleType.daily,
          time: _timeValue(time),
          doseAmount: _dose.text.trim(),
          startDate: _start,
          endDate: _end,
          timezone: timezone,
        );
      }).toList();

      try {
        await _scheduleService.createSchedules(
          medicationId: medicationId,
          patientId: patientId,
          schedules: extras,
        );
      } catch (_) {
        // The medication itself was created. A later provider refresh can
        // reconcile schedules without blocking the save result.
      }
    }

    if (!mounted) return;
    setState(() => _submitting = false);

    if (ok) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.read<MedicationProvider>().error ??
                localizations.unexpectedError,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(localizations.newMedicine)),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            children: [
              _imageCard(),
              const SizedBox(height: 22),
              _header('1', 'بيانات الدواء'),
              const SizedBox(height: 10),
              _formSelector(),
              const SizedBox(height: 14),
              TextFormField(
                controller: _name,
                decoration: InputDecoration(
                  labelText: localizations.medicineName,
                  prefixIcon: const Icon(Icons.medication_rounded),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? localizations.enterMedicineName
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _strength,
                decoration: InputDecoration(
                  labelText: localizations.strength,
                  hintText: 'مثال: 500 mg',
                  prefixIcon: const Icon(Icons.science_rounded),
                ),
              ),
              const SizedBox(height: 22),
              _header('2', 'الجرعة والتوقيت'),
              const SizedBox(height: 10),
              _frequencySelector(),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _frequencyHint(),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _dose,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'كمية الجرعة',
                        prefixIcon: const Icon(Icons.exposure_plus_1_rounded),
                        suffixText: _unitLabel(_unit),
                        helperText: _formHint(),
                      ),
                      validator: (value) =>
                          _validatePositive(value, 'الجرعة'),
                    ),
                  ),
                  if (_frequency == _Frequency.timesPerDay) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _times,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'مرات/اليوم',
                          suffixText: 'مرات',
                        ),
                        validator: (value) {
                          final count = int.tryParse(value ?? '');
                          return count == null || count < 1 || count > 6
                              ? '1 إلى 6'
                              : null;
                        },
                      ),
                    ),
                  ],
                  if (_frequency == _Frequency.everyHours) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _hours,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'الفاصل',
                          suffixText: 'ساعات',
                        ),
                        validator: (value) {
                          final hours = int.tryParse(value ?? '');
                          return hours == null ||
                                  hours <= 0 ||
                                  hours > 24 ||
                                  24 % hours != 0
                              ? '4/6/8/12/24'
                              : null;
                        },
                      ),
                    ),
                  ],
                ],
              ),
              if (_frequency != _Frequency.prn) ...[
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.access_time_rounded),
                    title: const Text('أول وقت للجرعة'),
                    subtitle: const Text('سيتم إنشاء بقية الأوقات تلقائيًا حسب النمط.'),
                    trailing: Text(
                      _time.format(context),
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    onTap: _pickTime,
                  ),
                ),
              ],
              if (_frequency == _Frequency.specificDays) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: List.generate(7, (index) {
                    final day = index + 1;
                    return FilterChip(
                      label: Text(localizations.weekdayLabel(day)),
                      selected: _days.contains(day),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _days.add(day);
                          } else {
                            _days.remove(day);
                          }
                        });
                      },
                    );
                  }),
                ),
              ],
              if (_frequency == _Frequency.prn) ...[
                const SizedBox(height: 10),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.health_and_safety_rounded),
                    title: const Text('دواء عند الحاجة'),
                    subtitle: const Text(
                      'لن يتم إنشاء أوقات ثابتة. استخدم تسجيل الجرعة عند استعمال الدواء.',
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 22),
              _header('3', 'المخزون'),
              const SizedBox(height: 8),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'تتبع المخزون',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  'الوحدة الحالية: ${_unitLabel(_unit)} — سيُستخدم معدل الجرعة لعرض الأيام المتبقية.',
                ),
                value: _stockEnabled,
                onChanged: (value) => setState(() => _stockEnabled = value),
              ),
              if (_stockEnabled) ...[
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _stock,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: 'الكمية الحالية',
                          suffixText: _unitLabel(_unit),
                        ),
                        validator: (value) {
                          final number = _number(value ?? '');
                          return number == null || number < 0
                              ? 'قيمة صحيحة'
                              : null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _pack,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: 'محتوى العبوة',
                          suffixText: _unitLabel(_unit),
                        ),
                        validator: (value) {
                          if ((value ?? '').trim().isEmpty) return null;
                          final number = _number(value!);
                          return number == null || number <= 0
                              ? 'قيمة صحيحة'
                              : null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _threshold,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'حد المخزون المنخفض',
                    suffixText: _unitLabel(_unit),
                  ),
                  validator: (value) {
                    final number = _number(value ?? '');
                    return number == null || number < 0
                        ? 'قيمة صحيحة'
                        : null;
                  },
                ),
              ],
              const SizedBox(height: 22),
              _header('4', 'مدة العلاج والتعليمات'),
              const SizedBox(height: 8),
              _dateTile(
                'تاريخ البدء',
                DateTimeUtils.formatShortDate(_start),
                () => _pickDate(true),
              ),
              _dateTile(
                'تاريخ الانتهاء',
                _end == null ? 'بدون تاريخ انتهاء' : DateTimeUtils.formatShortDate(_end!),
                () => _pickDate(false),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _instructions,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: localizations.instructionsOptional,
                  hintText: 'مثال: بعد الأكل، مع كوب ماء…',
                  prefixIcon: const Icon(Icons.notes_rounded),
                ),
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: localizations.saveMedicine,
                onPressed: _submit,
                loading: _submitting,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(String number, String text) => Row(
        children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: AppColors.primary,
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 9),
          Text(
            text,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
        ],
      );

  Widget _formSelector() => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _forms.map((form) {
          return ChoiceChip(
            avatar: Icon(_formIcon(form), size: 18),
            label: Text(form),
            selected: _form == form,
            onSelected: (_) {
              setState(() {
                _form = form;
                _unit = _units[form]!;
                if (form == 'قرص' || form == 'كبسولة') {
                  _dose.text = '1';
                } else if (form == 'شراب') {
                  _dose.text = '5';
                } else if (form == 'قطرة') {
                  _dose.text = '2';
                }
              });
            },
          );
        }).toList(),
      );

  IconData _formIcon(String form) {
    switch (form) {
      case 'قرص':
        return Icons.circle_outlined;
      case 'كبسولة':
        return Icons.medication_rounded;
      case 'شراب':
        return Icons.local_drink_rounded;
      case 'قطرة':
        return Icons.water_drop_rounded;
      case 'حقنة':
        return Icons.vaccines_rounded;
      case 'كريم/مرهم':
        return Icons.clean_hands_rounded;
      case 'بخاخ':
        return Icons.air_rounded;
      default:
        return Icons.medical_services_rounded;
    }
  }

  Widget _frequencySelector() => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _freq('مرة يوميًا', _Frequency.daily),
          _freq('مرات في اليوم', _Frequency.timesPerDay),
          _freq('كل X ساعات', _Frequency.everyHours),
          _freq('أيام محددة', _Frequency.specificDays),
          _freq('مرة واحدة', _Frequency.once),
          _freq('عند الحاجة', _Frequency.prn),
        ],
      );

  Widget _freq(String text, _Frequency frequency) => ChoiceChip(
        label: Text(text),
        selected: _frequency == frequency,
        onSelected: (_) => setState(() => _frequency = frequency),
      );

  Widget _dateTile(String title, String value, VoidCallback tap) => Card(
        child: ListTile(
          leading: const Icon(Icons.event_rounded),
          title: Text(title),
          trailing: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          onTap: tap,
        ),
      );

  Widget _imageCard() => InkWell(
        onTap: _pickImage,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          height: 150,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: AppColors.primary.withValues(alpha: .07),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: _image == null
              ? const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_a_photo_rounded,
                      size: 38,
                      color: AppColors.primary,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'إضافة صورة الدواء',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                )
              : ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Image.memory(
                    _image!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                  ),
                ),
        ),
      );
}
