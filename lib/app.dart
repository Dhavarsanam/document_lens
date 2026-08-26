import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:document_lens/core/theme/app_theme.dart';
import 'package:document_lens/providers/theme_provider.dart';
import 'package:document_lens/providers/auth_provider.dart';
import 'package:document_lens/screens/auth/login_screen.dart';
import 'package:document_lens/screens/auth/register_screen.dart';
import 'package:document_lens/screens/splash/splash_screen.dart';
import 'package:document_lens/screens/main_wrapper.dart';
import 'package:document_lens/screens/ocr_result/ocr_result_screen.dart';
import 'package:document_lens/screens/privacy_blur/privacy_blur_screen.dart';
import 'package:document_lens/screens/scan_calendar/scan_calendar_screen.dart';
import 'package:document_lens/screens/notebook/notebook_screen.dart';
import 'package:document_lens/screens/camera/camera_stabilizer_screen.dart';
import 'package:document_lens/screens/reminders/reminder_screen.dart';
import 'package:document_lens/screens/image_enhancement/image_enhancement_screen.dart';
import 'package:document_lens/screens/quality_checker/quality_checker_screen.dart';
import 'package:document_lens/screens/edge_detection/edge_detection_screen.dart';
import 'package:document_lens/screens/pdf_annotation/pdf_annotation_screen.dart'; // ✅ NEW
import 'package:document_lens/models/document_model.dart';

class DocumentLensApp extends StatelessWidget {
  const DocumentLensApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    return MaterialApp(
      title: 'DOCMIND',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/main': (context) => const _AuthGuard(child: MainWrapper()),

        '/result': (context) =>
        const _AuthGuard(child: OcrResultScreen()),

        // Privacy Blur
        // Accepts either a DocumentModel (saved doc — blur choice gets
        // PERSISTED so it shows everywhere) or a raw String (fresh,
        // not-yet-saved scan — blur choice is local to this screen until
        // the doc is saved).
        '/privacy_blur': (context) {
          final args = ModalRoute.of(context)!.settings.arguments;
          final doc = args is DocumentModel ? args : null;
          final text = args is DocumentModel
              ? args.extractedText
              : (args as String? ?? '');
          return _AuthGuard(
            child: PrivacyBlurScreen(extractedText: text, document: doc),
          );
        },

        // Scan to Calendar
        '/scan_calendar': (context) => _AuthGuard(
          child: ScanCalendarScreen(
            extractedText:
            ModalRoute.of(context)!.settings.arguments
            as String? ??
                '',
          ),
        ),

        // Digital Notebook
        '/notebook': (context) =>
        const _AuthGuard(child: NotebookScreen()),

        // Camera Stabilizer
        '/camera_stabilizer': (context) =>
        const _AuthGuard(child: CameraStabilizerScreen()),

        // Reminders
        '/reminders': (context) => _AuthGuard(
          child: ReminderScreen(
            documentTitle:
            ModalRoute.of(context)!.settings.arguments as String?,
          ),
        ),

        // Image Enhancement
        '/image_enhance': (context) => _AuthGuard(
          child: ImageEnhancementScreen(
            imageFile: ModalRoute.of(context)!.settings.arguments
            as File,
          ),
        ),

        // Quality Checker
        '/quality_check': (context) => _AuthGuard(
          child: QualityCheckerScreen(
            imageFile: ModalRoute.of(context)!.settings.arguments
            as File,
          ),
        ),

        // Edge Detection
        '/edge_detect': (context) => _AuthGuard(
          child: EdgeDetectionScreen(
            imageFile: ModalRoute.of(context)!.settings.arguments
            as File,
          ),
        ),

        // ✅ NEW - PDF Annotation
        '/pdf_annotate': (context) => _AuthGuard(
          child: PdfAnnotationScreen(
            imageFile: ModalRoute.of(context)!.settings.arguments
            as File,
          ),
        ),
      },
    );
  }
}

class _AuthGuard extends StatelessWidget {
  final Widget child;
  const _AuthGuard({required this.child});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.status == AuthStatus.initial ||
        auth.status == AuthStatus.loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (auth.status == AuthStatus.unauthenticated) {
      return const LoginScreen();
    }

    return child;
  }
}