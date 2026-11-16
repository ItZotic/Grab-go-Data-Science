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
  });

  test('order persists across sign-out and sign-in again', () async {
    final campusId = Database.builtInCampusId;

    // Admin sign-in (built-in)
    final err = await AppState.instance.signIn(Database.builtInAdminEmail, Database.builtInAdminPassword);
    expect(err, isNull);

    // Create a stall and link a stall admin
    final stall = await Database.createStall(
      campusId: campusId,
      name: 'Test Stall',
      blurb: '',
      categories: ['Rice meal'],
      personName: 'Rosa',
      adminEmail: 'rosa-test@batstate-u.edu.ph',
    );
    await Database.createAccount(
      campusId: campusId,
      name: 'Rosa',
      email: 'rosa-test@batstate-u.edu.ph',
      password: 'Admin#123',
      role: AccountRole.stallAdmin,
      type: AccountType.employee,
      stallId: stall.id,
    );

    // Add a dish
    await Database.createDish(campusId: campusId, stallId: stall.id, name: 'Pork Sisig', description: '', price: 75, servings: 10, category: 'Rice meal', liveTray: true);

    // Register a customer
    final regErr = await AppState.instance.registerCustomerAsync(
      name: 'Customer One',
      schoolId: '23-00001',
      type: 'Student',
      email: 'customer1@batstate-u.edu.ph',
      password: 'Customer#123',
    );
    expect(regErr, isNull);
    expect(AppState.instance.currentUser?.email, 'customer1@batstate-u.edu.ph');

    // Add to cart & place an order
    final dish = Database.dishes(campusId, stallId: stall.id).first;
    AppState.instance.addToCart(dish, qty: 2);
    final nowMin = DateTime.now().hour * 60 + DateTime.now().minute;
    final slot = Database.slots(campusId: campusId, stallId: stall.id).firstWhere((s) => s.startMin > nowMin && s.open);
    final order = await AppState.instance.placeOrder(stall: stall, slot: slot, method: PayMethod.counter, payRef: '');
    expect(order, isNotNull);

    // Verify it appears in "My orders"
    final mine = AppState.instance.myOrders();
    expect(mine.length, 1, reason: 'Order should appear in customer orders');

    // Sign out (forces private collections to unbind + clear)
    AppState.instance.signOut();
    expect(AppState.instance.currentUser, isNull);

    // Sign back in as the customer
    final err2 = await AppState.instance.signIn('customer1@batstate-u.edu.ph', 'Customer#123');
    expect(err2, isNull);
    final mine2 = AppState.instance.myOrders();
    expect(mine2.length, 1, reason: 'Order should persist across sign-out and sign-in again');
  });
}
