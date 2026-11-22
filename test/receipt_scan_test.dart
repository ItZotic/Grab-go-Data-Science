import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

import 'package:grab_go/src/db.dart';
import 'package:grab_go/src/stall/scan.dart';

const _options = FirebaseOptions(apiKey: 'fake', appId: 'fake', messagingSenderId: 'fake', projectId: 'fake', storageBucket: 'fake');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final firestore = FakeFirebaseFirestore();
    final auth = MockFirebaseAuth();
    await Database.init(firestore: firestore, auth: auth, options: _options);
  });

  testWidgets('ScanReceiptScreen renders camera and upload controls', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ScanReceiptScreen(),
      ),
    );

    expect(find.text('Scan receipt QR'), findsOneWidget);
    expect(find.text('Camera scan'), findsOneWidget);
    expect(find.text('Upload photo'), findsOneWidget);
    expect(find.text('Flash off'), findsOneWidget);

    // Tap flash
    await tester.tap(find.text('Flash off'));
    await tester.pump();
    expect(find.text('Flash on'), findsOneWidget);

    // Test manual input
    await tester.enterText(find.byType(TextField), 'GG-0042');
    await tester.tap(find.byIcon(Icons.arrow_forward_rounded));
    await tester.pumpAndSettle();
  });
}
