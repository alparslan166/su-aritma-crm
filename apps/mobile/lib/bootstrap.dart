import "dart:async";

import "package:firebase_core/firebase_core.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "app.dart";
import "core/notifications/push_notification_service.dart";

Future<void> bootstrap() async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      
      // Initialize Firebase (optional - will fail gracefully if not configured)
      try {
        await Firebase.initializeApp();
        debugPrint("Firebase initialized");
      } catch (e) {
        debugPrint("Firebase initialization skipped (not configured): $e");
        // Continue without Firebase if not configured
      }
      
      runApp(const ProviderScope(child: SuAritmaApp()));
    },
    (error, stackTrace) {
      debugPrint("Unhandled error: $error");
      debugPrintStack(stackTrace: stackTrace);
    },
  );
}
