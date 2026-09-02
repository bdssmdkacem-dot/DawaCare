import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../core/widgets/loading_indicator.dart';
import '../../../../models/medication.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../doses/domain/dose_engine.dart';
import '../providers/medication_provider.dart';
import 'add_edit_medication_page.dart';

class MedicationListPage extends StatefulWidget {
  const MedicationListPage({super.key});

  @override
  State<MedicationListPage> createState() => _MedicationListPageState();
}

class _MedicationListPageState extends State<MedicationListPage> {
  bool _loadedOnce = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loadedOnce) {
      _loadedOnce = true;
      final userId = context.read<AuthProvider>().profile?.id;
      if (userId != null) context.read<MedicationProvider>().load(userId);
    }
  }

  Future<void> _changeImage(Medication medication) async {
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
    if (source == null || !mounted) return;

    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 82,
    );
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;

    final ok = await context.read<MedicationProvider>().updateMedicationImage(medication, bytes);
    if (!mounted || ok) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.read<MedicationProvider>().error ?? 'تعذّر تحديث الصورة')),
    );
  }

  Future<void> _removeImage(Medication medication) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف صورة الدواء؟'),
        content: const Text('سيبقى الدواء والجرعات كما هي، وستُحذف الصورة فقط.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف الصورة')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<MedicationProvider>().removeMedicationImage(medication);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MedicationProvider>();
    final userId = context.read<AuthProvider>().profile?.id;

    return Scaffold(
      appBar: AppBar(title: const Text('أدويتي')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final medicationProvider = context.read<MedicationProvider>();
          final added = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const AddMedicationPage()),
          );
          if (!mounted) return;
          if (added == true && userId != null) await medicationProvider.load(userId);
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('دواء جديد'),
      ),
      body: _buildBody(provider),
    );
  }

  Widget _buildBody(MedicationProvider provider) {
    if (provider.isLoading && provider.medications.isEmpty) return const LoadingIndicator();
    if (provider.medications.isEmpty) {
      return const EmptyState(
        icon: Icons.medication_outlined,
        title: 'لم تُضِف أي دواء بعد',
        subtitle: 'اضغط على "دواء جديد" لإضافة أول دواء وتحديد موعده',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: provider.medications.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final med = provider.medications[index];
        final schedules = provider.schedulesByMedicationId[med.id] ?? const [];
        return _MedicationTile(
          medication: med,
          scheduleLabel: schedules.isNotEmpty ? DoseEngine.describeSchedule(schedules.first) : null,
          imageUrlFuture: provider.signedMedicationImageUrl(med.imageUrl),
          onChangeImage: () => _changeImage(med),
          onRemoveImage: med.imageUrl == null ? null : () => _removeImage(med),
          onDeactivate: () => _confirmDeactivate(med),
        );
      },
    );
  }

  Future<void> _confirmDeactivate(Medication medication) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إيقاف هذا الدواء؟'),
        content: Text('لن تُنشأ جرعات جديدة لـ${medication.name}. يمكنك إضافته من جديد لاحقًا.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('إيقاف')),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    await context.read<MedicationProvider>().deactivate(medication);
  }
}

class _MedicationTile extends StatelessWidget {
  final Medication medication;
  final String? scheduleLabel;
  final Future<String?> imageUrlFuture;
  final VoidCallback onChangeImage;
  final VoidCallback? onRemoveImage;
  final VoidCallback onDeactivate;

  const _MedicationTile({
    required this.medication,
    required this.scheduleLabel,
    required this.imageUrlFuture,
    required this.onChangeImage,
    required this.onRemoveImage,
    required this.onDeactivate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: FutureBuilder<String?>(
          future: imageUrlFuture,
          builder: (context, snapshot) {
            if (snapshot.data == null) {
              return CircleAvatar(
                backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
                child: Icon(Icons.medication_liquid_rounded, color: theme.colorScheme.primary),
              );
            }
            return ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                snapshot.data!,
                width: 58,
                height: 58,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => CircleAvatar(
                  backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
                  child: Icon(Icons.medication_liquid_rounded, color: theme.colorScheme.primary),
                ),
              ),
            );
          },
        ),
        title: Text(medication.name, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text([
          if (medication.strength != null && medication.strength!.isNotEmpty) medication.strength!,
          if (scheduleLabel != null) scheduleLabel!,
        ].join(' · ')),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'change_image') onChangeImage();
            if (value == 'remove_image') onRemoveImage?.call();
            if (value == 'deactivate') onDeactivate();
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'change_image', child: Text('تغيير صورة الدواء')),
            if (onRemoveImage != null)
              const PopupMenuItem(value: 'remove_image', child: Text('حذف صورة الدواء')),
            const PopupMenuItem(value: 'deactivate', child: Text('إيقاف الدواء')),
          ],
        ),
      ),
    );
  }
}
