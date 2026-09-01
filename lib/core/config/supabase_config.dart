/// Supabase connection settings.
///
/// This project is already provisioned (see supabase/README.md) — project
/// ref `lwdwlfhytdetziqfbgje`, region eu-west-3 (Paris). The defaults below
/// point at that live project, so `flutter run` works with no extra flags.
///
/// For CI/CD (GitHub Actions) and release builds, override via
/// `--dart-define` instead so a rotated key never requires a code change:
///
///   flutter build appbundle \
///     --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///     --dart-define=SUPABASE_ANON_KEY=sb_publishable_...
///
/// Both values (URL + anon/publishable key) are safe to ship in the client —
/// they are protected by Row Level Security, not secrecy. Never put the
/// `service_role` key in the app.
class SupabaseConfig {
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://lwdwlfhytdetziqfbgje.supabase.co',
  );

  static const String publishableKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_NqPkzToL2OQo5Zs3UOTkYw_vd0HAHdY',
  );

  static bool get isConfigured =>
      !url.contains('YOUR-PROJECT-REF') && !publishableKey.startsWith('YOUR-');
}
