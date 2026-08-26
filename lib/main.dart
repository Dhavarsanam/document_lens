import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:document_lens/app.dart';
import 'package:document_lens/firebase_options.dart';
import 'package:document_lens/models/document_model.dart';
import 'package:document_lens/models/scan_memory_model.dart';
import 'package:document_lens/models/notebook_model.dart';
import 'package:document_lens/models/reminder_model.dart'; // ✅ NEW
import 'package:document_lens/providers/document_provider.dart';
import 'package:document_lens/providers/ocr_provider.dart';
import 'package:document_lens/providers/theme_provider.dart';
import 'package:document_lens/providers/auth_provider.dart';
import 'package:document_lens/providers/smart_memory_provider.dart';
import 'package:document_lens/providers/notebook_provider.dart';
import 'package:document_lens/providers/reminder_provider.dart'; // ✅ NEW
import 'package:document_lens/services/notification_service.dart'; // ✅ NEW
import 'package:document_lens/services/demo_data_service.dart';

void main() {
  // ✅ Global crash-guard: catches EVERY uncaught Dart exception
  // (async errors, provider errors, background isolate errors) so a
  // single bad exception can no longer force-close the whole app.
  runZonedGuarded<void>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // ✅ Catches widget-build/layout errors. Without this, Flutter's
    // default behaviour on a build error can bubble up and kill the app;
    // now it just shows a friendly fallback screen for that one widget
    // and the rest of the app keeps running.
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      debugPrint('⚠️ Flutter error caught: ${details.exceptionAsString()}');
    };
    ErrorWidget.builder = (FlutterErrorDetails details) {
      // ✅ Wrapped in its own Directionality — this fallback can fire
      // BEFORE MaterialApp/Directionality exists in the tree (e.g. an
      // error during initial boot). Without this, the Icon below throws
      // "No Directionality widget found", which triggers ErrorWidget
      // again, which throws again — infinite recursion → Stack Overflow.
      return Directionality(
        textDirection: TextDirection.ltr,
        child: Material(
          color: Colors.black87,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: Colors.redAccent, size: 40),
                  const SizedBox(height: 12),
                  const Text(
                    'Something went wrong on this screen.\nPlease go back and try again.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    };

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    // ✅ Firebase backend init. Wrapped so a config/network issue doesn't
    // block the whole app from launching (Hive still works as local cache).
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e) {
      debugPrint('⚠️ Firebase init error (continuing with local-only mode): $e');
    }

    // ✅ Hive is now used only as a LOCAL CACHE for documents/notes/etc —
    // login/user identity is fully handled by Firebase Auth (no more
    // 'users'/'session' Hive boxes).
    try {
      await Hive.initFlutter();
      Hive.registerAdapter(DocumentModelAdapter());
      Hive.registerAdapter(ScanMemoryModelAdapter());
      Hive.registerAdapter(SubjectModelAdapter());
      Hive.registerAdapter(NoteModelAdapter());
      Hive.registerAdapter(ReminderModelAdapter()); // ✅ NEW

      await Hive.openBox<DocumentModel>('documents');
      await Hive.openBox<ScanMemoryModel>('scan_memory');
      await Hive.openBox<SubjectModel>('subjects');
      await Hive.openBox<NoteModel>('notes');
      await Hive.openBox<ReminderModel>('reminders'); // ✅ NEW
      await Hive.openBox('settings');
    } catch (e, st) {
      debugPrint('⚠️ Hive init error (continuing anyway): $e\n$st');
    }

    try {
      // Initialize notifications
      await NotificationService.initialize();
      await NotificationService.requestPermissions(); // ✅ ask once at startup
    } catch (e) {
      debugPrint('⚠️ Notification init error (continuing anyway): $e');
    }

    try {
      await DemoDataService.seedIfEmpty();
    } catch (e) {
      debugPrint('⚠️ Demo data seed error (continuing anyway): $e');
    }

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          // lazy: false => app start aana udane session check aagi,
          // account create/login pannavanga splash piragu direct dashboard ku polaam.
          ChangeNotifierProvider(create: (_) => AuthProvider(), lazy: false),
          ChangeNotifierProvider(create: (_) => OcrProvider()),
          ChangeNotifierProvider(create: (_) => DocumentProvider()),
          ChangeNotifierProvider(create: (_) => SmartMemoryProvider()),
          ChangeNotifierProvider(create: (_) => NotebookProvider()),
          ChangeNotifierProvider(create: (_) => ReminderProvider()), // ✅ NEW
        ],
        child: const DocumentLensApp(),
      ),
    );
  }, (Object error, StackTrace stack) {
    // Anything that slips past every try/catch above lands here —
    // logged instead of taking the whole app down.
    debugPrint('🔴 Uncaught error caught by runZonedGuarded: $error\n$stack');
  });
}