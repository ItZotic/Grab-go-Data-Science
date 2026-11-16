import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

import 'package:grab_go/src/app_state.dart';
import 'package:grab_go/src/db.dart';

const _options = FirebaseOptions(apiKey: 'fake', appId: 'fake', messagingSenderId: 'fake', projectId: 'fake', storageBucket: 'fake');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirebaseFirestore firestore;
  late MockFirebaseAuth auth;

  setUpAll(() async {
    firestore = FakeFirebaseFirestore();
    auth = MockFirebaseAuth();
    await Database.init(firestore: firestore, auth: auth, options: _options);
    await Database.clearEverythingExceptCampus();
  });

  test('admin-created customer can sign in with the generated temporary password', () async {
    final campusId = Database.builtInCampusId;

    const email = 'newcustomer@batstate-u.edu.ph';
    const temp = 'Grab&Go#12345';
    await Database.createAccount(
      campusId: campusId,
      name: 'Juan Dela Cruz',
      email: email,
      password: temp,
      role: AccountRole.customer,
      schoolId: '23-77777',
    );

    AppState.instance.signOut();
    final error = await AppState.instance.signIn(email, temp);
    expect(error, isNull, reason: 'Admin-created customer must be able to log in');
    expect(AppState.instance.currentUser?.email, email);
    AppState.instance.signOut();
  });

  test('customer created with no school ID can log in (ID check skipped)', () async {
    final campusId = Database.builtInCampusId;
    const email = 'noida@batstate-u.edu.ph';
    const temp = 'Grab&Go#54321';
    await Database.createAccount(
      campusId: campusId,
      name: 'Maria Santos',
      email: email,
      password: temp,
      role: AccountRole.customer,
      schoolId: '',
    );

    AppState.instance.signOut();
    final error = await AppState.instance.signIn(email, temp);
    expect(error, isNull);
    AppState.instance.signOut();
  });
}
