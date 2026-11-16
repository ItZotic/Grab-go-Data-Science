import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'src/app_state.dart';
import 'src/auth_screens.dart';
import 'src/db.dart';
import 'src/firebase_options.dart';
import 'src/theme.dart';
import 'src/widgets.dart';
import 'src/customer/customer_shell.dart';
import 'src/stall/stall_shell.dart';
import 'src/admin/admin_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // The Android google-services plugin initializes Firebase natively before Dart runs,
  // so only bootstrap here if nothing exists yet (web has no native init).
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    }
  } catch (e, stack) {
    // A duplicate-app race just means Firebase is already up — not fatal.
    if (!e.toString().contains('duplicate-app')) {
      runApp(MaterialApp(
        debugShowCheckedModeBanner: false,
        home: _BootErrorScreen(error: '$e\n\n$stack'),
      ));
      return;
    }
  }

  AppState.instance.init();
  runApp(const GrabGoApp());
}

class _BootErrorScreen extends StatelessWidget {
  const _BootErrorScreen({required this.error});
  final String error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1B33),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              const Icon(Icons.error_outline_rounded, color: Color(0xFFF5B301), size: 40),
              const SizedBox(height: 12),
              const Text('Grab&Go couldn’t start', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              const Text('Firebase failed to initialize on this device. The error below is what to send us:', style: TextStyle(color: Color(0xFFB9B7D6), fontSize: 12.5, height: 1.45)),
              const SizedBox(height: 14),
              Expanded(
                child: SingleChildScrollView(
                  child: SelectableText(error, style: const TextStyle(color: Color(0xFFE8E6F5), fontSize: 10.5, height: 1.5, fontFamily: 'monospace')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GrabGoApp extends StatelessWidget {
  const GrabGoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Grab&Go',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const _Gate(),
    );
  }
}

class _Gate extends StatelessWidget {
  const _Gate();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final state = AppState.instance;
        if (state.initError != null) {
          return Scaffold(
            backgroundColor: AppColors.yellow,
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const GrabLogo(size: 84),
                    const SizedBox(height: 16),
                    const Text('Storage failed to start', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.navy900)),
                    const SizedBox(height: 10),
                    SelectableText(
                      state.initError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: AppColors.navy800, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        if (!state.isInitialized) {
          return const Scaffold(
            backgroundColor: AppColors.yellow,
            body: SafeArea(
              child: Center(child: GrabLogo(size: 110, splash: true)),
            ),
          );
        }
        final user = state.currentUser;
        if (user == null) return const GateScreen();
        // Role-based routing (also restores a persisted session silently).
        switch (user.role) {
          case AccountRole.stallAdmin:
            return const StallShell();
          case AccountRole.mainAdmin:
            return const AdminShell();
          default:
            return const CustomerShell();
        }
      },
    );
  }
}
