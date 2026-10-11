import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toastification/toastification.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'core/shaders/shader_service.dart';
import 'presentation/providers/audio_providers.dart';
import 'presentation/screens/shell/app_shell.dart';
import 'services/audio_player_handler.dart';
import 'services/home_widget_service.dart';
import 'services/intent_handler_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LiquidGlassWidgets.initialize();
  // Pre-warm GPU fragment shaders in background for instantaneous first-frame rendering
  ShaderService.instance.preloadAll();
  
  // Enable GoogleFonts to load from local bundled assets immediately on startup
  GoogleFonts.config.allowRuntimeFetching = true;
  
  // Bound image memory cache to prevent memory spikes on low-RAM devices
  PaintingBinding.instance.imageCache.maximumSize = 250;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 60 * 1024 * 1024; // 60 MB

  // Initialize SharedPreferences for persistent preferences and theme state
  final sharedPreferences = await SharedPreferences.getInstance();
  final preferencesService = PreferencesService(sharedPreferences);

  // Initialize background Audio Service
  final audioHandler = await AudioService.init(
    builder: () => MusifyAudioHandler(preferencesService: preferencesService),
    config: const AudioServiceConfig(
      androidNotificationChannelId: AppConstants.audioChannelId,
      androidNotificationChannelName: AppConstants.audioChannelName,
      androidNotificationChannelDescription: AppConstants.audioChannelDescription,
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      androidNotificationIcon: 'mipmap/ic_launcher',
      
    ),
  );

  // Initialize Home Screen Widget synchronization
  HomeWidgetService.initialize(audioHandler);

  // Initialize "Open With" audio files and shared link handling
  IntentHandlerService.initialize(audioHandler);

  runApp(
    ProviderScope(
      overrides: [
        audioHandlerProvider.overrideWithValue(audioHandler),
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      ],
      child: const MusifyApp(),
    ),
  );
}

class MusifyApp extends ConsumerWidget {
  const MusifyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return LiquidGlassWidgets.wrap(
      brightnessResolver: Theme.maybeBrightnessOf,
      adaptiveQuality: true,
      child: ToastificationWrapper(
        child: MaterialApp(
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,
          home: const AppShell(),
        ),
      ),
    );
  }
}

