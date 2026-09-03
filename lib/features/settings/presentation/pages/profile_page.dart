import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/profile/profile_avatar_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  bool _saving = false;
  bool _avatarBusy = false;

  @override
  void initState() {
    super.initState();
    final profile = context.read<AuthProvider>().profile;
    _nameController = TextEditingController(text: profile?.fullName ?? '');
    _phoneController = TextEditingController(text: profile?.phone ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final profile = context.watch<AuthProvider>().profile;
    final email = Supabase.instance.client.auth.currentUser?.email ?? '';

    if (profile == null) {
      return Scaffold(
        appBar: AppBar(title: Text(_tr(context, 'الملف الشخصي', 'Profile', 'Profil'))),
        body: Center(child: Text(_tr(context, 'لا توجد بيانات الملف الشخصي.', 'Profile data is unavailable.', 'Les données du profil sont indisponibles.'))),
      );
    }

    final initials = _initials(profile.fullName);
    final hasAvatar = profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: Text(_tr(context, 'الملف الشخصي', 'Profile', 'Profil')), centerTitle: false),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.78)]),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 44,
                        backgroundColor: Colors.white.withValues(alpha: 0.18),
                        backgroundImage: hasAvatar ? NetworkImage(profile.avatarUrl!) : null,
                        child: hasAvatar
                            ? null
                            : Text(initials, style: const TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w800)),
                      ),
                      Material(
                        color: Colors.white,
                        shape: const CircleBorder(),
                        elevation: 3,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _avatarBusy ? null : _changeAvatar,
                          child: Padding(
                            padding: const EdgeInsets.all(9),
                            child: _avatarBusy
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.camera_alt_rounded, color: AppColors.primary, size: 19),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(profile.fullName.isEmpty ? l.appName : profile.fullName, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(_tr(context, 'حسابك في DawaCare', 'Your DawaCare account', 'Votre compte DawaCare'), style: TextStyle(color: Colors.white.withValues(alpha: 0.86))),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: _avatarBusy ? null : _changeAvatar,
                    icon: const Icon(Icons.photo_camera_rounded, size: 18),
                    label: Text(_tr(context, 'تغيير صورة الملف الشخصي', 'Change profile photo', 'Changer la photo de profil')),
                    style: TextButton.styleFrom(foregroundColor: Colors.white),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _sectionHeader(context, Icons.person_outline_rounded, _tr(context, 'المعلومات الشخصية', 'Personal information', 'Informations personnelles')),
            const SizedBox(height: 10),
            Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(labelText: l.fullName, prefixIcon: const Icon(Icons.person_outline_rounded)),
                      validator: (value) => value == null || value.trim().isEmpty ? _tr(context, 'أدخل الاسم الكامل.', 'Enter your full name.', 'Saisissez votre nom complet.') : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(labelText: _tr(context, 'رقم الهاتف', 'Phone', 'Téléphone'), prefixIcon: const Icon(Icons.phone_outlined)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            _sectionHeader(context, Icons.info_outline_rounded, _tr(context, 'معلومات الحساب', 'Account information', 'Informations du compte')),
            const SizedBox(height: 10),
            _infoCard(context, Icons.email_outlined, l.email, email.isEmpty ? '—' : email),
            const SizedBox(height: 10),
            _infoCard(context, Icons.family_restroom_rounded, _tr(context, 'رمز العائلة', 'Family code', 'Code famille'), profile.familyCode.isEmpty ? '—' : profile.familyCode, copyValue: profile.familyCode.isEmpty ? null : profile.familyCode),
            const SizedBox(height: 10),
            _infoCard(context, Icons.public_rounded, _tr(context, 'المنطقة الزمنية', 'Timezone', 'Fuseau horaire'), profile.timezone),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_rounded),
              label: Text(_saving ? _tr(context, 'جارٍ الحفظ...', 'Saving...', 'Enregistrement...') : _tr(context, 'حفظ', 'Save', 'Enregistrer')),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54), backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _changeAvatar() async {
    if (_avatarBusy) return;
    setState(() => _avatarBusy = true);
    try {
      final url = await ProfileAvatarService.instance.pickAndUpload();
      if (!mounted) return;
      if (url != null) {
        await context.read<AuthProvider>().refreshProfile();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_tr(context, 'تم تحديث صورة الملف الشخصي.', 'Profile photo updated.', 'Photo de profil mise à jour.'))));
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_tr(context, 'تعذر رفع الصورة. حاول مرة أخرى.', 'Could not upload the photo. Please try again.', 'Impossible de téléverser la photo. Réessayez.'))));
    } finally {
      if (mounted) setState(() => _avatarBusy = false);
    }
  }

  Widget _sectionHeader(BuildContext context, IconData icon, String title) => Row(children: [Icon(icon, size: 20, color: AppColors.primary), const SizedBox(width: 8), Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))]);

  Widget _infoCard(BuildContext context, IconData icon, String title, String value, {String? copyValue}) => Card(
        elevation: 0,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          leading: CircleAvatar(backgroundColor: AppColors.primary.withValues(alpha: 0.10), child: Icon(icon, color: AppColors.primary)),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Padding(padding: const EdgeInsets.only(top: 3), child: Text(value)),
          trailing: copyValue == null ? null : IconButton(
            tooltip: _tr(context, 'نسخ', 'Copy', 'Copier'),
            icon: const Icon(Icons.copy_rounded),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: copyValue));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_tr(context, 'تم نسخ رمز العائلة.', 'Family code copied.', 'Code famille copié.'))));
            },
          ),
        ),
      );

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final profile = auth.profile;
    if (profile == null) return;
    setState(() => _saving = true);
    try {
      await auth.updateProfile(profile.copyWith(fullName: _nameController.text.trim(), phone: _phoneController.text.trim()));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_tr(context, 'تم حفظ الملف الشخصي بنجاح.', 'Profile saved successfully.', 'Profil enregistré avec succès.'))));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_tr(context, 'تعذر حفظ التغييرات. حاول مرة أخرى.', 'Could not save changes. Please try again.', 'Impossible d’enregistrer les modifications. Réessayez.'))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _initials(String name) {
    final value = name.trim();
    if (value.isEmpty) return '?';
    return value.split(RegExp(r'\s+')).map((e) => e[0]).take(2).join().toUpperCase();
  }

  String _tr(BuildContext context, String ar, String en, String fr) {
    switch (Localizations.localeOf(context).languageCode) {
      case 'en': return en;
      case 'fr': return fr;
      default: return ar;
    }
  }
}
