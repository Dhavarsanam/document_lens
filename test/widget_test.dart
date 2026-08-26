import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:document_lens/app.dart';
import 'package:document_lens/providers/ocr_provider.dart';
import 'package:document_lens/providers/document_provider.dart';
import 'package:document_lens/models/document_model.dart';
import 'package:flutter/material.dart';

void main() {
  setUpAll(() async {
    await Hive.initFlutter();
    Hive.registerAdapter(DocumentModelAdapter());
    await Hive.openBox<DocumentModel>('documents');
  });

  testWidgets('App launches successfully', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => OcrProvider()),
          ChangeNotifierProvider(create: (_) => DocumentProvider()),
        ],
        child: const DocumentLensApp(),
      ),
    );
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}