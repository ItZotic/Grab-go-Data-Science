import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'db.dart';

enum ClaimResult { ok, notFound, alreadyClaimed, released }

String peso(num value) => '₱${value.toStringAsFixed(2)}';

String orderNoDisplay(String orderNo) => '#$orderNo';

const List<String> _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String shortDate(DateTime d) => '${_months[d.month - 1]} ${d.day}';
String shortDateYear(DateTime d) => '${_months[d.month - 1]} ${d.day}, ${d.year}';

String clockTime(DateTime d) {
  final pm = d.hour >= 12;
  var h = d.hour % 12;
  if (h == 0) h = 12;
  final m = d.minute.toString().padLeft(2, '0');
  return '$h:$m ${pm ? 'PM' : 'AM'}';
}

String monthDayLabel(DateTime d) => '${_months[d.month - 1]} ${d.day}';

class CartLine {
  CartLine(this.dish, [this.qty = 1]);
  final Dish dish;
  int qty;
  double get total => dish.price * qty;
}

/// Session + cart + operations. Everything goes through the database;
/// notifyListeners() drives all reactive UI.
class AppState extends ChangeNotifier {
  AppState._();
  static final AppState instance = AppState._();

  Account? currentUser;
  Campus? campus;
  final List<CartLine> cart = [];

  bool _initialized = false;
  bool get isInitialized => _initialized;
  String? _initError;
  String? get initError => _initError;

  Timer? _releaseTimer;

  /// Mark orders whose pickup window + grace period has passed as Released,
  /// and notify their customers. Any signed-in campus user may do this per rules.
  Future<void> _sweepStaleOrders() async {
    try {
      final n = await Database.releaseStaleOrders(requiredCampus.id);
      if (n > 0) notifyListeners();
    } catch (_) {}
  }

  void _startReleaseTimer() {
    _releaseTimer?.cancel();
    _releaseTimer = Timer.periodic(const Duration(minutes: 1), (_) => _sweepStaleOrders());
  }

  void _stopReleaseTimer() {
    _releaseTimer?.cancel();
    _releaseTimer = null;
  }

  Future<void> init() async {
    try {
      // Runs the Firebase bootstrap + attaches live snapshot listeners.
      await Database.init();
      // Reactive UI: whenever Firestore emits, rebuild widgets.
      Database.onChanged = notifyListeners;

      final authUser = Database.appAuth.currentUser;
      if (authUser != null) {
        // Private collections must be bound before the account doc is readable.
        await Database.bindSessionCollections();
        final account = Database.accountById(authUser.uid);
        if (account != null && account.active) {
          currentUser = account;
          campus = Database.defaultCampus();
          // Only staff can write orders (Firestore rules), so only staff sweeps.
          if (account.role == AccountRole.stallAdmin || account.role == AccountRole.mainAdmin) {
            await _sweepStaleOrders();
            _startReleaseTimer();
          }
        } else {
          await Database.unbindSessionCollections();
          await Database.appAuth.signOut();
        }
      }
    } catch (e, stack) {
      _initError = '$e\n\n$stack';
      try {
        final sp = await SharedPreferences.getInstance();
        await sp.setString('initError', '$e\n\n$stack');
      } catch (_) {}
    }
    _initialized = true;
    try {
      final sp = await SharedPreferences.getInstance();
      if (_initError == null) {
        await sp.remove('initError');
      }
    } catch (_) {}
    notifyListeners();
  }

  // ---------------------------------------------------------- session
  Campus get requiredCampus => campus ?? Database.defaultCampus();

  bool get hasCampus => campus != null;

  /// Firebase Auth sign-in — shared emails, correct verification, cross-device sessions.
  Future<String?> signIn(String email, String password) async {
    final normalized = email.trim().toLowerCase();
    try {
      final cred = await Database.appAuth.signInWithEmailAndPassword(email: normalized, password: password);
      final uid = cred.user!.uid;
      // Private collections must be bound before account lookups succeed.
      await Database.bindSessionCollections();
      var account = Database.accountById(uid);
      // Aliased installs/re-issued Auth IDs can differ from the stored doc id —
      // fall back to an email lookup as the requester's own account doc (rules allow it).
      account ??= await Database.findAccountByEmail(normalized);
      if (account == null) {
        await Database.appAuth.signOut();
        return 'No profile for this account. Visit the canteen office.';
      }
      if (!account.active) {
        await Database.appAuth.signOut();
        return 'This account has been deactivated. Please visit the canteen office.';
      }
      currentUser = account;
      campus = Database.defaultCampus();
      // Only staff can write orders (Firestore rules), so only staff sweeps.
      if (account.role == AccountRole.stallAdmin || account.role == AccountRole.mainAdmin) {
        await _sweepStaleOrders();
        _startReleaseTimer();
      }
      notifyListeners();
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') return 'No account found for "$email".';
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') return 'Incorrect password. Passwords must be at least 8 characters.';
      if (e.code == 'user-disabled') return 'This account has been deactivated.';
      return 'Could not sign in (${e.code}).';
    } catch (e) {
      return 'Could not sign in: $e';
    }
  }

  /// Customer self-registration. Staff/admin accounts are created by the office.
  /// Returns null on success, or a user-facing validation message.
  Future<String?> registerCustomerAsync({
    required String name,
    required String schoolId,
    required String type,
    required String email,
    required String password,
  }) async {
    final target = Database.defaultCampus();
    final emailRx = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');
    final idRx = RegExp(target.idPattern);

    final trimmedName = name.trim();
    if (trimmedName.isEmpty) return 'Full name is required.';
    final normalizedEmail = email.trim().toLowerCase();
    if (!emailRx.hasMatch(normalizedEmail)) return 'Enter a valid email, like name@${target.domain}.';
    if (Database.accountByEmail(normalizedEmail, campusId: target.id) != null) {
      return 'This email is already registered.';
    }
    final trimmedId = schoolId.trim();
    if (type != 'Visitor') {
      if (trimmedId.isEmpty) return 'School ID is required.';
      if (!idRx.hasMatch(trimmedId)) return 'School ID must look like ${target.idHint}.';
    }
    if (password.length < 8) return 'Password must be at least 8 characters.';

    final accountType = switch (type) {
      'Faculty' => AccountType.faculty,
      'Employee' => AccountType.employee,
      'Visitor' => AccountType.visitor,
      _ => AccountType.student,
    };

    // Create an Auth user + profile doc (register happens under the customer role).
    // signInNewUser makes sure the profile doc is written while we're signed in as the new user.
    final account = await Database.createAccount(
      campusId: target.id,
      name: trimmedName,
      email: normalizedEmail,
      password: password,
      role: AccountRole.customer,
      type: accountType,
      schoolId: trimmedId,
      signInNewUser: true,
    );
    // Switch this device to the new account's session.
    await Database.appAuth.signInWithEmailAndPassword(email: normalizedEmail, password: password);
    await Database.bindSessionCollections();
    currentUser = account;
    campus = target;
    notifyListeners();
    return null;
  }

  void signOut() {
    _stopReleaseTimer();
    currentUser = null;
    campus = null;
    cart.clear();
    Database.appAuth.signOut();
    // Private collections are unreadable signed-out; unbind + clear them.
    Database.unbindSessionCollections();
    notifyListeners();
  }

  /// Force UI rebuild (e.g. after direct Database writes from admin screens).
  void refresh() => notifyListeners();

  // ---------------------------------------------------------- notes
  List<Note> notesFor(String userId) => Database.notes(requiredCampus.id, userId);

  List<Note> get myNotes => currentUser == null ? const [] : Database.notes(requiredCampus.id, currentUser!.id);

  int get unreadCount => myNotes.where((n) => !n.read).length;

  Future<void> markAllNotesRead() async {
    if (currentUser == null) return;
    await Database.markNotesRead(requiredCampus.id, currentUser!.id);
    notifyListeners();
  }

  Future<void> _note(String userId, String title, String body, String kind) =>
      Database.pushNote(campusId: requiredCampus.id, userId: userId, title: title, body: body, kind: kind);

  // ---------------------------------------------------------- cart
  int get cartCount => cart.fold(0, (a, l) => a + l.qty);
  double get cartTotal => cart.fold(0, (a, l) => a + l.total);

  CartLine? lineFor(String dishId) {
    for (final l in cart) {
      if (l.dish.id == dishId) return l;
    }
    return null;
  }

  int qtyInCart(String dishId) => lineFor(dishId)?.qty ?? 0;

  bool canAdd(Dish dish) => qtyInCart(dish.id) < dish.servingsLeft;

  void addToCart(Dish dish, {int qty = 1}) {
    final current = qtyInCart(dish.id);
    final allowed = (dish.servingsLeft - current).clamp(0, qty);
    if (allowed <= 0) return;
    final existing = lineFor(dish.id);
    if (existing != null) {
      existing.qty += allowed;
    } else {
      cart.add(CartLine(dish, allowed));
    }
    notifyListeners();
  }

  void setLineQty(String dishId, int qty) {
    final line = lineFor(dishId);
    if (line == null) return;
    if (qty <= 0) {
      cart.remove(line);
    } else {
      line.qty = qty.clamp(1, line.dish.servingsLeft < 1 ? 1 : line.dish.servingsLeft);
    }
    notifyListeners();
  }

  void removeLine(String dishId) {
    cart.removeWhere((l) => l.dish.id == dishId);
    notifyListeners();
  }

  void clearCart() {
    cart.clear();
    notifyListeners();
  }

  // ---------------------------------------------------------- customer
  List<Stall> customerStalls() => Database.stalls(requiredCampus.id, status: StallStatus.active);

  List<Dish> dishesForStall(String stallId) => Database.dishes(requiredCampus.id, stallId: stallId).where((d) => d.available).toList();

  List<Dish> trayCounterDishes() {
    final out = <Dish>[];
    for (final stall in customerStalls()) {
      out.addAll(Database.dishes(requiredCampus.id, stallId: stall.id).where((d) => d.available && d.liveTray && d.servingsLeft > 0));
    }
    out.sort((a, b) => a.servingsLeft.compareTo(b.servingsLeft));
    return out;
  }

  List<Slot> slotsFor(String stallId) => Database.slots(campusId: requiredCampus.id, stallId: stallId);

  List<OrderRec> myOrders() {
    if (currentUser == null) return const [];
    return Database.orders(requiredCampus.id, customerId: currentUser!.id);
  }

  OrderRec? findOrder(String orderNo) => Database.orderByNo(orderNo, campusId: requiredCampus.id);

  Future<OrderRec?> placeOrder({
    required Stall stall,
    required Slot slot,
    required PayMethod method,
    required String payRef,
  }) async {
    if (currentUser == null || cart.isEmpty) return null;
    if (slot.full || !slot.open) return null;

    final items = [
      for (final l in cart) OrderItem(dishId: l.dish.id, name: l.dish.name, qty: l.qty, price: l.dish.price),
    ];
    final order = await Database.placeOrder(campusId: requiredCampus.id, customer: currentUser!, stall: stall, items: items, slot: slot, method: method, payRef: payRef);
    clearCart();
    await _note(currentUser!.id, 'Order placed · #${order.orderNo}', 'Pickup ${order.slotLabel} at ${stall.name}. Show your receipt.', 'success');
    notifyListeners();
    return order;
  }

  // ---------------------------------------------------------- stall admin
  Stall? get myStall {
    final uid = currentUser?.stallId;
    if (uid == null) return null;
    return Database.stallById(uid);
  }

  List<OrderRec> stallOrders(String stallId) => Database.orders(requiredCampus.id, stallId: stallId);

  Future<String?> markReady(String orderId) async {
    final order = Database.orderById(orderId, campusId: requiredCampus.id);
    if (order == null) return 'Order not found.';
    await Database.updateOrderStatus(order, OrderStatus.ready);
    await _note(order.customerId, 'Your order is ready', 'Order #${order.orderNo} is ready at ${order.stallName}. Claim it at the express lane.', 'success');
    notifyListeners();
    return null;
  }

  Future<ClaimResult> claimOrder(String orderNo, {required String claimedBy}) async {
    final order = Database.orderByNo(orderNo, campusId: requiredCampus.id);
    if (order == null) return ClaimResult.notFound;
    if (order.status == OrderStatus.claimed) return ClaimResult.alreadyClaimed;
    if (order.status == OrderStatus.released) return ClaimResult.released;
    await Database.updateOrderStatus(order, OrderStatus.claimed, claimedBy: claimedBy);
    await _note(order.customerId, 'Order claimed', '#${order.orderNo} was marked claimed. Enjoy your meal!', 'success');
    notifyListeners();
    return ClaimResult.ok;
  }

  Future<String?> createDish({
    required String stallId,
    required String name,
    required String description,
    required double price,
    required int servings,
    required String category,
    required bool liveTray,
    int? iconIndex,
    int? colorIndex,
    String? photo,
  }) async {
    final existing = Database.dishByName(name, stallId: stallId);
    if (existing != null) return 'A dish with this name is already on the menu.';
    await Database.createDish(campusId: requiredCampus.id, stallId: stallId, name: name, description: description, price: price, servings: servings, category: category, liveTray: liveTray, iconIndex: iconIndex, colorIndex: colorIndex, photo: photo);
    notifyListeners();
    return null;
  }

  Future<void> updateDish(Dish dish) async {
    await Database.updateDish(dish);
    notifyListeners();
  }

  Future<void> deleteDish(String id) async {
    await Database.deleteDish(id);
    notifyListeners();
  }

  Future<void> adjustServings(Dish dish, int delta) async {
    await Database.updateDish(dish.copyWith(servingsLeft: (dish.servingsLeft + delta).clamp(0, 999)));
    notifyListeners();
  }

  Future<void> setServings(Dish dish, int servings) async {
    await Database.updateDish(dish.copyWith(servingsLeft: servings.clamp(0, 999)));
    notifyListeners();
  }

  /// Sales between [from] and [to] (inclusive) for a stall (or all stalls if null).
  /// Filtered by order date (placedAt) — use for order counts and no-show rate.
  List<OrderRec> ordersBetween({String? stallId, DateTime? from, DateTime? to}) {
    final all = Database.orders(requiredCampus.id, stallId: stallId);
    return all.where((o) {
      if (from != null && o.placedAt.isBefore(DateTime(from.year, from.month, from.day))) return false;
      if (to != null && o.placedAt.isAfter(DateTime(to.year, to.month, to.day, 23, 59, 59))) return false;
      return true;
    }).toList();
  }

  /// True when the money for this order has actually reached the stall.
  /// Counter (pay at pickup) orders count only once claimed; GCash/QRPh are prepaid.
  bool isPaid(OrderRec o) => o.payment == PayMethod.counter ? o.status == OrderStatus.claimed : true;

  /// Date the money counts for: counter → claim date; online prepaid → order date.
  DateTime revenueDateOf(OrderRec o) => o.payment == PayMethod.counter ? (o.claimedAt ?? o.placedAt) : o.placedAt;

  /// Revenue-eligible orders (money actually collected) between [from]/[to],
  /// bucketed by payment date. Use this for every money figure.
  List<OrderRec> paymentsBetween({String? stallId, DateTime? from, DateTime? to}) {
    final all = Database.orders(requiredCampus.id, stallId: stallId);
    return all.where((o) {
      if (!isPaid(o)) return false;
      final d = revenueDateOf(o);
      if (from != null && d.isBefore(DateTime(from.year, from.month, from.day))) return false;
      if (to != null && d.isAfter(DateTime(to.year, to.month, to.day, 23, 59, 59))) return false;
      return true;
    }).toList();
  }

  /// Sums only money that arrived (counter-paid orders count once claimed).
  double revenueOf(List<OrderRec> orders) => orders.where(isPaid).fold(0, (a, o) => a + o.total);

  List<MapEntry<String, int>> topDishesOf(List<OrderRec> orders, {int limit = 5}) {
    final counts = <String, int>{};
    for (final o in orders) {
      for (final i in o.items) {
        counts[i.name] = (counts[i.name] ?? 0) + i.qty;
      }
    }
    final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(limit).toList();
  }

  // ---------------------------------------------------------- main admin
  Future<String?> createStallWithAdmin({
    required String name,
    required String blurb,
    required List<String> categories,
    required String personName,
    required String adminEmail,
    required String tempPassword,
  }) async {
    if (name.trim().isEmpty) return 'Stall name is required.';
    if (personName.trim().isEmpty) return 'Person in charge is required.';
    final emailRx = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');
    final normalized = adminEmail.trim().toLowerCase();
    if (!emailRx.hasMatch(normalized)) return 'Enter a valid login email for the stall admin.';
    if (Database.stallByName(name) != null) return 'A stall with this name already exists.';
    if (Database.accountByEmail(normalized, campusId: requiredCampus.id) != null) return 'An account with this email already exists.';

    final stall = await Database.createStall(campusId: requiredCampus.id, name: name, blurb: blurb, categories: categories, personName: personName, adminEmail: normalized);
    await Database.createAccount(campusId: requiredCampus.id, name: personName, email: normalized, password: tempPassword, role: AccountRole.stallAdmin, type: AccountType.employee, schoolId: 'EMP-${stall.name.hashCode.abs() % 1000}', stallId: stall.id);
    final admin = Database.accountByEmail(Database.builtInAdminEmail, campusId: requiredCampus.id);
    if (admin != null) {
      await _note(admin.id, 'Stall created', '${stall.name} is now accepting orders.', 'success');
    }
    notifyListeners();
    return null;
  }

  Future<String?> approveStallRequest(String stallId) async {
    final stall = Database.stallById(stallId);
    if (stall == null) return 'Request not found.';
    final email = stall.adminEmail;
    String password;
    do {
      password = 'Stall#${(DateTime.now().millisecondsSinceEpoch % 100000).toString().padLeft(5, '0')}';
    } while (password.length < 8);

    if (Database.accountByEmail(email, campusId: stall.campusId) != null) {
      await Database.updateStall(stall.copyWith(status: StallStatus.active));
      notifyListeners();
      return 'Approved. (Note: an account with $email already existed — password was left unchanged.)';
    }
    await Database.updateStall(stall.copyWith(status: StallStatus.active));
    await Database.createAccount(campusId: stall.campusId, name: stall.personName, email: email, password: password, role: AccountRole.stallAdmin, type: AccountType.employee, schoolId: 'EMP-${stall.name.hashCode.abs() % 1000}', stallId: stall.id);
    notifyListeners();
    return 'Approved. Stall admin credentials: $email / $password';
  }

  Future<void> declineStallRequest(String stallId) async {
    final stall = Database.stallById(stallId);
    if (stall == null) return;
    await Database.updateStall(stall.copyWith(status: StallStatus.suspended));
    notifyListeners();
  }

  Future<void> setStallSuspended(String stallId, bool suspended) async {
    final stall = Database.stallById(stallId);
    if (stall == null) return;
    await Database.updateStall(stall.copyWith(status: suspended ? StallStatus.suspended : StallStatus.active));
    notifyListeners();
  }

  /// Triggers a Firebase password-reset email to the account's address.
  Future<String?> resetAccountPassword(String accountId, String newPassword) =>
      Database.resetPassword(accountId, campusId: requiredCampus.id, newPassword: newPassword).then((e) {
        notifyListeners();
        return e;
      });

  Future<String?> setAccountActive(String accountId, bool active) => Database.setAccountActive(accountId, active: active).then((_) {
        notifyListeners();
        return null;
      });

  Future<String?> deleteAccount(String accountId) =>
      Database.deleteAccount(accountId, campusId: requiredCampus.id, currentUserId: currentUser!.id).then((e) {
        notifyListeners();
        return e;
      });

}
