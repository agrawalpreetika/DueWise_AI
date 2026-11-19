import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';

import 'features/subscriptions/subscription_model.dart';
import 'features/subscriptions/payment_log_model.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/auth_provider.dart';
import 'main_navigation_screen.dart';
import 'services/notification_service.dart'; // Cleaned up duplicate import
import 'theme/theme_provider.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Firebase Core Initialize
  // 1. Firebase Core Initialize with DefaultFirebaseOptions
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await Hive.initFlutter();

  // Register Adapters
  Hive.registerAdapter(SubscriptionAdapter());
  Hive.registerAdapter(PaymentLogAdapter());

  // Open Boxes
  await Hive.openBox<Subscription>('subscriptions');
  await Hive.openBox<PaymentLog>('payment_logs');

  // Initialize notifications (permissions are requested inside init method)
  final notificationService = NotificationService();
  await notificationService.init();

  runApp(const ProviderScope(child: DueWiseApp()));
}

class DueWiseApp extends ConsumerWidget {
  const DueWiseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    // Current Theme Mode ko watch karein
    final themeMode = ref.watch(themeNotifierProvider);

    return MaterialApp(
      title: 'DueWise',
      debugShowCheckedModeBanner: false,

      // Light Mode Theme
      theme: AppTheme.lightTheme,

      // Dark Mode Theme
      darkTheme: AppTheme.darkTheme,

      // Dynamic Theme Shift (Light / Dark)
      themeMode: themeMode,

      home: authState.when(
        data: (user) =>
            user != null ? const MainNavigationScreen() : const LoginScreen(),
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (err, stack) => const LoginScreen(),
      ),
    );
  }
}
