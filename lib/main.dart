import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/presentation/auth_screen.dart';
import 'features/home/presentation/home_screen.dart';
import 'features/profile/presentation/phone_gate_screen.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'core/providers/localization_provider.dart';
import 'core/providers/theme_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/supabase_config.dart';
import 'core/push/push_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // dotenv MUST resolve first — SupabaseConfig and the Mapbox token both
  // read from it. Then run Supabase + Firebase in parallel.
  await dotenv.load(fileName: '.env');

  MapboxOptions.setAccessToken(dotenv.env['MAPBOX_PUBLIC_TOKEN'] ?? '');

  await Future.wait([
    Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    ),
    Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)
        .catchError((_) => Firebase.app()),
  ]);

  runApp(const ProviderScope(child: MyApp()));

  // Push registration touches the network (FCM token + Supabase upsert) — push
  // it after the first frame so the user sees UI immediately.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    PushService.instance.initialize().catchError((_) {});
  });
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final locale = ref.watch(localizationProvider);
    final themeMode = ref.watch(themeProvider);

    return MaterialApp(
      title: 'Food Delivery',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'), // English
        Locale('ar'), // Arabic
        Locale('fr'), // French
      ],
      home: authState.when(
        data: (user) {
          if (user != null) {
            return const _PostAuthGate();
          }
          return const AuthScreen();
        },
        loading: () => const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
        error: (error, stack) => const AuthScreen(),
      ),
    );
  }
}

/// After sign-in, require the customer to have a phone number on their
/// `profiles` row before reaching the main app. Without one, drivers can't
/// reach the customer about deliveries, which breaks the COD flow.
class _PostAuthGate extends StatefulWidget {
  const _PostAuthGate();

  @override
  State<_PostAuthGate> createState() => _PostAuthGateState();
}

class _PostAuthGateState extends State<_PostAuthGate> {
  Future<bool>? _phoneReady;

  @override
  void initState() {
    super.initState();
    _phoneReady = _checkPhone();
  }

  void _recheck() {
    if (!mounted) return;
    setState(() {
      _phoneReady = _checkPhone();
    });
  }

  Future<bool> _checkPhone() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return false;
    try {
      final row = await Supabase.instance.client
          .from('profiles')
          .select('phone')
          .eq('id', userId)
          .maybeSingle();
      final phone = row?['phone'] as String?;
      return phone != null && phone.trim().isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _phoneReady,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.data == true) {
          return const HomeScreen();
        }
        return PopScope(
          canPop: false,
          child: PhoneGateScreen(onSaved: _recheck),
        );
      },
    );
  }
}
