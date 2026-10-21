import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'config/theme.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'services/socket_service.dart';
import 'services/tracking_service.dart';
import 'services/location_service.dart';
import 'services/background_service.dart';
import 'services/monitor_service.dart';
import 'services/gallery_sync_service.dart';
import 'services/update_service.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/permissions_setup_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  await BackgroundService.initialize();

  final apiService = ApiService();
  final authService = AuthService(apiService);
  final socketService = SocketService();
  final monitorService = MonitorService(apiService);
  final galleryService = GallerySyncService(apiService);
  final updateService = UpdateService();
  // Pull last-installed sha256 into memory before anyone calls checkForUpdates().
  await updateService.hydrate();

  runApp(NoxApp(
    apiService: apiService,
    authService: authService,
    socketService: socketService,
    monitorService: monitorService,
    galleryService: galleryService,
    updateService: updateService,
  ));
}

class NoxApp extends StatelessWidget {
  final ApiService apiService;
  final AuthService authService;
  final SocketService socketService;
  final MonitorService monitorService;
  final GallerySyncService galleryService;
  final UpdateService updateService;

  const NoxApp({
    super.key,
    required this.apiService,
    required this.authService,
    required this.socketService,
    required this.monitorService,
    required this.galleryService,
    required this.updateService,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiService>.value(value: apiService),
        ChangeNotifierProvider<AuthService>.value(value: authService),
        ChangeNotifierProvider<SocketService>.value(value: socketService),
        Provider<TrackingService>(
          create: (_) => TrackingService(apiService, socketService),
        ),
        Provider<LocationService>(
          create: (_) => LocationService(socketService, apiService),
        ),
        Provider<MonitorService>.value(value: monitorService),
        Provider<GallerySyncService>.value(value: galleryService),
        ChangeNotifierProvider<UpdateService>.value(value: updateService),
      ],
      child: MaterialApp(
        title: 'NOX',
        debugShowCheckedModeBanner: false,
        theme: NoxTheme.darkTheme,
        initialRoute: '/splash',
        routes: {
          '/splash': (_) => const SplashScreen(),
          '/login': (_) => const LoginScreen(),
          '/home': (_) => const HomeScreen(),
          '/permissions': (_) => PermissionsSetupScreen(
                onDone: () {
                  // Navigate handled inside HomeScreen after permissions
                },
              ),
        },
      ),
    );
  }
}
