import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

import 'package:grab_go/main.dart';
import 'package:grab_go/src/app_state.dart';
import 'package:grab_go/src/db.dart';

const _options = FirebaseOptions(apiKey: 'fake', appId: 'fake', messagingSenderId: 'fake', projectId: 'fake', storageBucket: 'fake');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Inject fakes, init DB, then initialize AppState (gate watches for it).
    await Database.init(firestore: FakeFirebaseFirestore(), auth: MockFirebaseAuth(), options: _options);
    await AppState.instance.init();
  });

  testWidgets('Grab&Go boots into the yellow splash, then role selection', (tester) async {
    await tester.pumpWidget(const GrabGoApp());

    expect(find.text('Grab&Go'), findsOneWidget);
    expect(find.text('Order ahead. Eat longer.'), findsOneWidget);

    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(find.text('I am a…'), findsOneWidget);
  });
}
