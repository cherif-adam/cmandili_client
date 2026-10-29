/// What the app needs to know at build time, passed with
/// `flutter run` / `flutter build ... --dart-define-from-file=dart_defines.json`
/// (copy dart_defines.example.json; the real file is git-ignored).
///
/// These values used to come from `.env`, bundled in the APK as an asset:
/// anyone could unzip the APK and read every line of it, an OpenRouter API
/// key included. Only public values live here now: the Supabase anon key is
/// public by design (row-level security guards the data) and the Maps key is
/// restricted to the app. Secrets belong in Edge Functions.
class BuildConfig {
  BuildConfig._();

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Directions and Places calls. Empty: those features turn themselves off.
  static const googleMapsApiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');

  /// The values this build cannot start without, empty when it has them.
  static List<String> get missing => [
        if (supabaseUrl.isEmpty) 'SUPABASE_URL',
        if (supabaseAnonKey.isEmpty) 'SUPABASE_ANON_KEY',
      ];
}
