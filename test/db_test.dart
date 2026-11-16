import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

import 'package:grab_go/src/app_state.dart';
import 'package:grab_go/src/db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirebaseFirestore firestore;
  late MockFirebaseAuth auth;

  setUpAll(() async {
    firestore = FakeFirebaseFirestore();
    auth = MockFirebaseAuth();
    await Database.init(
      firestore: firestore,
      auth: auth,
      options: const FirebaseOptions(apiKey: 'fake', appId: 'fake', messagingSenderId: 'fake', projectId: 'fake', storageBucket: 'fake'),
    );
    // Bind private (auth-gated) collections — needed before account assertions.
    await Database.bindSessionCollections();
    // Start from a pristine database (structure only: campus + built-in admin).
    await Database.clearEverythingExceptCampus();
  });

  test('fresh install keeps data empty: only campus + built-in admin', () async {
    expect(Database.campusList().length, 1);
    expect(Database.campusList().first.name, 'Batangas State University');

    final accounts = Database.accounts(Database.builtInCampusId);
    expect(accounts.length, 1);
    expect(accounts.first.email, Database.builtInAdminEmail);
    expect(accounts.first.role, AccountRole.mainAdmin);

    expect(Database.stalls(Database.builtInCampusId), isEmpty);
    expect(Database.dishes(Database.builtInCampusId), isEmpty);
    expect(Database.orders(Database.builtInCampusId), isEmpty);
  });

  test('built-in admin can sign in with the built-in credentials', () async {
    final error = await AppState.instance.signIn(Database.builtInAdminEmail, Database.builtInAdminPassword);
    expect(error, isNull);
    expect(AppState.instance.currentUser?.email, Database.builtInAdminEmail);
  });

  test('full order lifecycle: stall -> dish -> register -> order -> claim', () async {
    final campusId = Database.builtInCampusId;

    // Admin creates a stall.
    final stall = await Database.createStall(
      campusId: campusId,
      name: 'Sisig Corner',
      blurb: 'Sizzling chopped pork',
      categories: ['Rice meal'],
      personName: 'Mang Rey',
      adminEmail: 'rey@batstate-u.edu.ph',
    );
    expect(Database.stalls(campusId).length, 1);

    // Standing windows were generated for the full 7am-7pm day.
    final slots = Database.slots(campusId: campusId, stallId: stall.id);
    expect(slots.length, 72);

    // Stall admin adds a dish.
    await Database.createDish(campusId: campusId, stallId: stall.id, name: 'Pork Sisig', description: '', price: 75, servings: 5, category: 'Rice meal', liveTray: true);
    final dish = Database.dishes(campusId).first;
    expect(dish.servingsLeft, 5);

    // Customer registers.
    final registerError = await AppState.instance.registerCustomerAsync(
      name: 'Janna Reyes',
      schoolId: '23-12345',
      type: 'Student',
      email: 'janna@batstate-u.edu.ph',
      password: 'Password#123',
    );
    expect(registerError, isNull);

    // Customer orders 2 servings against the first window.
    AppState.instance.addToCart(Database.dishes(campusId).first, qty: 2);
    final nowMin = DateTime.now().hour * 60 + DateTime.now().minute;
    final slot = slots.firstWhere((s) => s.startMin > nowMin && s.open);
    final order = await AppState.instance.placeOrder(
      stall: stall,
      slot: slot,
      method: PayMethod.counter,
      payRef: '',
    );
    expect(order, isNotNull);
    expect(order!.orderNo, 'GG-0001');

    // Stock decremented and slot booked.
    expect(Database.dishes(campusId).first.servingsLeft, 3);
    final bookedSlot = Database.slots(campusId: campusId, stallId: stall.id).firstWhere((s) => s.id == slot.id);
    expect(bookedSlot.booked, 1);

    // Stall admin claims the order; claimed receipt can never be reused.
    final claimed = await AppState.instance.claimOrder(order.orderNo, claimedBy: 'Mang Rey');
    expect(claimed, ClaimResult.ok);
    expect(Database.orders(campusId).first.status, OrderStatus.claimed);

    final reused = await AppState.instance.claimOrder(order.orderNo, claimedBy: 'Mang Rey');
    expect(reused, ClaimResult.alreadyClaimed);

    AppState.instance.signOut();
  });
}
