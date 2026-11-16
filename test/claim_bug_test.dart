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

  test('claiming one order of the same customer does not claim the others', () async {
    final campusId = Database.builtInCampusId;

    // Admin signs in.
    expect(await AppState.instance.signIn(Database.builtInAdminEmail, Database.builtInAdminPassword), isNull);

    // Create a stall and stall-admin account.
    final stall = await Database.createStall(
      campusId: campusId,
      name: 'TapSilog Stall',
      blurb: '',
      categories: ['Rice meal'],
      personName: 'Jana',
      adminEmail: 'jana@batstate-u.edu.ph',
    );
    await Database.createAccount(
      campusId: campusId,
      name: 'Jana',
      email: 'jana@batstate-u.edu.ph',
      password: 'Admin#123',
      role: AccountRole.stallAdmin,
      type: AccountType.employee,
      stallId: stall.id,
    );
    await Database.createAccount(
      campusId: campusId,
      name: 'Faye Carubio',
      email: 'faye@batstate-u.edu.ph',
      password: 'Customer#123',
      role: AccountRole.customer,
      schoolId: '24-09957',
    );

    // Stall admin adds a dish.
    await Database.createDish(campusId: campusId, stallId: stall.id, name: 'TapSilog', description: '', price: 65, servings: 10, category: 'Rice meal', liveTray: true);

    // Customer signs in and places two orders.
    AppState.instance.signOut();
    expect(await AppState.instance.signIn('faye@batstate-u.edu.ph', 'Customer#123'), isNull);
    final dish = Database.dishes(campusId, stallId: stall.id).first;

    AppState.instance.addToCart(dish, qty: 1);
    final nowMin = DateTime.now().hour * 60 + DateTime.now().minute;
    final slots = Database.slots(campusId: campusId, stallId: stall.id).where((s) => s.startMin > nowMin && s.open).toList();
    final order1 = await AppState.instance.placeOrder(stall: stall, slot: slots[0], method: PayMethod.counter, payRef: '');
    expect(order1, isNotNull);

    AppState.instance.addToCart(dish, qty: 1);
    final order2 = await AppState.instance.placeOrder(stall: stall, slot: slots[1], method: PayMethod.counter, payRef: '');
    expect(order2, isNotNull);
    expect(order1!.orderNo, isNot(order2!.orderNo));

    // Stall admin signs in and claims the first order.
    AppState.instance.signOut();
    expect(await AppState.instance.signIn('jana@batstate-u.edu.ph', 'Admin#123'), isNull);
    expect(await AppState.instance.claimOrder(order1.orderNo, claimedBy: 'Jana'), ClaimResult.ok);

    // Second order must be unchanged.
    final after = Database.orderByNo(order2.orderNo, campusId: campusId);
    expect(after, isNotNull);
    expect(after!.status, OrderStatus.preparing);
  });
}
