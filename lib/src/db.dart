import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart' show Firebase, FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'firebase_options.dart';

// ============================================================================
// GRAB&GO — Firebase backend
//
// Every document carries `campusId`. Queries are live snapshots so counters
// on every screen update the moment someone claims, orders, or restocks —
// that is what makes this multi-device.
// ============================================================================

enum AccountRole { customer, stallAdmin, mainAdmin }
enum AccountType { student, faculty, employee, visitor }
enum StallStatus { pending, active, suspended }
enum OrderStatus { preparing, ready, claimed, released }
enum PayMethod { counter, gcash, qrph }

/// Online payment (GCash/QRPh) is OFF until a real payment integration exists —
/// only Pay at counter is offered at checkout. Flip to true to re-enable the UI and flow.
const bool kOnlinePaymentsEnabled = false;
enum PayoutStatus { pending, paid }

String roleLabelOf(AccountRole r) {
  switch (r) {
    case AccountRole.customer:
      return 'Customer';
    case AccountRole.stallAdmin:
      return 'Stall admin';
    case AccountRole.mainAdmin:
      return 'Main admin';
  }
}

String typeLabelOf(AccountType t) {
  switch (t) {
    case AccountType.student:
      return 'Student';
    case AccountType.faculty:
      return 'Faculty';
    case AccountType.employee:
      return 'Employee';
    case AccountType.visitor:
      return 'Visitor';
  }
}

String orderStatusLabel(OrderStatus s) {
  switch (s) {
    case OrderStatus.preparing:
      return 'Preparing';
    case OrderStatus.ready:
      return 'Ready in 12 min';
    case OrderStatus.claimed:
      return 'Claimed';
    case OrderStatus.released:
      return 'Expired';
  }
}

String payMethodLabel(PayMethod m) {
  switch (m) {
    case PayMethod.counter:
      return 'Pay at the counter';
    case PayMethod.gcash:
      return 'GCash';
    case PayMethod.qrph:
      return 'QRPh';
  }
}

// ---------------------------------------------------------------- models
class Campus {
  Campus({required this.id, required this.name, required this.shortName, required this.domain, required this.idPattern, required this.idHint});
  final String id;
  final String name;
  final String shortName;
  final String domain;
  final String idPattern;
  final String idHint;

  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'shortName': shortName, 'domain': domain, 'idPattern': idPattern, 'idHint': idHint};
  factory Campus.fromMap(Map m) => Campus(id: m['id'], name: m['name'], shortName: m['shortName'], domain: m['domain'], idPattern: m['idPattern'], idHint: m['idHint']);
}

/// Account = Firestore `accounts/{uid}` (id matches the Firebase Auth UID).
/// Passwords are never stored — Firebase Auth owns them.
class Account {
  Account({
    required this.id,
    required this.campusId,
    required this.name,
    required this.email,
    required this.role,
    required this.type,
    required this.schoolId,
    this.stallId,
    this.active = true,
    required this.createdAt,
    this.colorIndex = 0,
  });

  final String id;
  final String campusId;
  final String name;
  final String email;
  final AccountRole role;
  final AccountType type;
  final String schoolId;
  final String? stallId;
  final bool active;
  final DateTime createdAt;
  final int colorIndex;

  String get initials {
    final p = name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (p.isEmpty) return '?';
    return (p.first[0] + (p.length > 1 ? p.last[0] : '')).toUpperCase();
  }

  Account copyWith({String? name, String? email, String? schoolId, AccountRole? role, AccountType? type, bool? active, String? stallId}) => Account(
        id: id,
        campusId: campusId,
        name: name ?? this.name,
        email: email ?? this.email,
        role: role ?? this.role,
        type: type ?? this.type,
        schoolId: schoolId ?? this.schoolId,
        stallId: stallId ?? this.stallId,
        active: active ?? this.active,
        createdAt: createdAt,
        colorIndex: colorIndex,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'campusId': campusId,
        'name': name,
        'email': email,
        'role': role.name,
        'type': type.name,
        'schoolId': schoolId,
        'stallId': stallId,
        'active': active,
        'createdAt': createdAt.toIso8601String(),
        'colorIndex': colorIndex,
      };

  factory Account.fromMap(Map m) => Account(
        id: m['id'],
        campusId: m['campusId'],
        name: m['name'],
        email: m['email'],
        role: AccountRole.values.firstWhere((r) => r.name == m['role'], orElse: () => AccountRole.customer),
        type: AccountType.values.firstWhere((t) => t.name == m['type'], orElse: () => AccountType.student),
        schoolId: m['schoolId'] ?? '—',
        stallId: m['stallId'],
        active: m['active'] ?? true,
        createdAt: DateTime.tryParse(m['createdAt'] ?? '') ?? DateTime.now(),
        colorIndex: m['colorIndex'] ?? 0,
      );
}

class Stall {
  Stall({
    required this.id,
    required this.campusId,
    required this.name,
    required this.blurb,
    required this.categories,
    required this.personName,
    required this.adminEmail,
    required this.status,
    required this.createdAt,
    this.colorIndex = 0,
    this.iconIndex = 0,
    this.photo,
    this.openMin = 7 * 60,
    this.closeMin = 19 * 60,
    this.slotCapacity = 20,
  });

  final String id;
  final String campusId;
  final String name;
  final String blurb;
  final List<String> categories;
  final String personName;
  final String adminEmail;
  final StallStatus status;
  final DateTime createdAt;
  final int colorIndex;
  final int iconIndex;
  final String? photo;
  final int openMin; // minutes since midnight — when this stall's first pickup window starts
  final int closeMin; // minutes since midnight — no windows are generated after this
  final int slotCapacity; // orders allowed per pickup window ("store limit")

  Stall copyWith({String? name, String? blurb, List<String>? categories, String? personName, StallStatus? status, int? colorIndex, int? iconIndex}) => Stall(
        id: id,
        campusId: campusId,
        name: name ?? this.name,
        blurb: blurb ?? this.blurb,
        categories: categories ?? this.categories,
        personName: personName ?? this.personName,
        adminEmail: adminEmail,
        status: status ?? this.status,
        createdAt: createdAt,
        colorIndex: colorIndex ?? this.colorIndex,
        iconIndex: iconIndex ?? this.iconIndex,
        photo: photo,
        openMin: openMin,
        closeMin: closeMin,
        slotCapacity: slotCapacity,
      );

  /// Force-set (or clear) the storefront photo.
  Stall withPhoto(String? photoBase64) => Stall(
        id: id,
        campusId: campusId,
        name: name,
        blurb: blurb,
        categories: categories,
        personName: personName,
        adminEmail: adminEmail,
        status: status,
        createdAt: createdAt,
        colorIndex: colorIndex,
        iconIndex: iconIndex,
        photo: photoBase64,
        openMin: openMin,
        closeMin: closeMin,
        slotCapacity: slotCapacity,
      );

  /// Force-set the pickup schedule + window limit.
  Stall withSchedule({required int openMin, required int closeMin, required int slotCapacity}) => Stall(
        id: id,
        campusId: campusId,
        name: name,
        blurb: blurb,
        categories: categories,
        personName: personName,
        adminEmail: adminEmail,
        status: status,
        createdAt: createdAt,
        colorIndex: colorIndex,
        iconIndex: iconIndex,
        photo: photo,
        openMin: openMin,
        closeMin: closeMin,
        slotCapacity: slotCapacity,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'campusId': campusId,
        'name': name,
        'blurb': blurb,
        'categories': categories,
        'personName': personName,
        'adminEmail': adminEmail,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'colorIndex': colorIndex,
        'iconIndex': iconIndex,
        'photo': photo,
        'openMin': openMin,
        'closeMin': closeMin,
        'slotCapacity': slotCapacity,
      };

  factory Stall.fromMap(Map m) => Stall(
        id: m['id'],
        campusId: m['campusId'],
        name: m['name'],
        blurb: m['blurb'] ?? '',
        categories: List<String>.from(m['categories'] ?? const []),
        personName: m['personName'] ?? '',
        adminEmail: m['adminEmail'] ?? '',
        status: StallStatus.values.firstWhere((s) => s.name == m['status'], orElse: () => StallStatus.active),
        createdAt: DateTime.tryParse(m['createdAt'] ?? '') ?? DateTime.now(),
        colorIndex: m['colorIndex'] ?? 0,
        iconIndex: m['iconIndex'] ?? 0,
        photo: m['photo'],
        openMin: m['openMin'] ?? 420,
        closeMin: m['closeMin'] ?? 1140,
        slotCapacity: m['slotCapacity'] ?? 20,
      );
}

class Dish {
  Dish({
    required this.id,
    required this.campusId,
    required this.stallId,
    required this.name,
    required this.description,
    required this.price,
    required this.servingsLeft,
    required this.initialStock,
    this.available = true,
    this.liveTray = true,
    this.isNew = false,
    this.createdAt,
    this.iconIndex = 0,
    this.colorIndex = 0,
    this.category = 'Rice meal',
    this.photo,
  });

  final String id;
  final String campusId;
  final String stallId;
  final String name;
  final String description;
  final double price;
  final int servingsLeft;
  final int initialStock;
  final bool available;
  final bool liveTray;
  final bool isNew;
  final DateTime? createdAt;
  final int iconIndex;
  final int colorIndex;
  final String category;
  final String? photo;

  Dish copyWith({String? name, String? description, double? price, int? servingsLeft, bool? available, bool? liveTray, bool? isNew, int? iconIndex, int? colorIndex, String? category, String? photo}) => Dish(
        id: id,
        campusId: campusId,
        stallId: stallId,
        name: name ?? this.name,
        description: description ?? this.description,
        price: price ?? this.price,
        servingsLeft: servingsLeft ?? this.servingsLeft,
        initialStock: initialStock,
        available: available ?? this.available,
        liveTray: liveTray ?? this.liveTray,
        isNew: isNew ?? this.isNew,
        createdAt: createdAt,
        iconIndex: iconIndex ?? this.iconIndex,
        colorIndex: colorIndex ?? this.colorIndex,
        category: category ?? this.category,
        photo: photo ?? this.photo,
      );

  /// Force-set (or clear) the dish photo.
  Dish withPhoto(String? photoBase64) => Dish(
        id: id,
        campusId: campusId,
        stallId: stallId,
        name: name,
        description: description,
        price: price,
        servingsLeft: servingsLeft,
        initialStock: initialStock,
        available: available,
        liveTray: liveTray,
        isNew: isNew,
        createdAt: createdAt,
        iconIndex: iconIndex,
        colorIndex: colorIndex,
        category: category,
        photo: photoBase64,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'campusId': campusId,
        'stallId': stallId,
        'name': name,
        'description': description,
        'price': price,
        'servingsLeft': servingsLeft,
        'initialStock': initialStock,
        'available': available,
        'liveTray': liveTray,
        'isNew': isNew,
        'createdAt': createdAt?.toIso8601String(),
        'iconIndex': iconIndex,
        'colorIndex': colorIndex,
        'category': category,
        'photo': photo,
      };

  factory Dish.fromMap(Map m) => Dish(
        id: m['id'],
        campusId: m['campusId'],
        stallId: m['stallId'],
        name: m['name'],
        description: m['description'] ?? '',
        price: (m['price'] as num?)?.toDouble() ?? 0,
        servingsLeft: m['servingsLeft'] ?? 0,
        initialStock: m['initialStock'] ?? 40,
        available: m['available'] ?? true,
        liveTray: m['liveTray'] ?? true,
        isNew: m['isNew'] ?? false,
        createdAt: DateTime.tryParse(m['createdAt'] ?? ''),
        iconIndex: m['iconIndex'] ?? 0,
        colorIndex: m['colorIndex'] ?? 0,
        category: m['category'] ?? 'Rice meal',
        photo: m['photo'],
      );
}

String ymd(DateTime d) => '${d.year.toString().padLeft(4, '0')}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';

class Slot {
  Slot({required this.id, required this.campusId, required this.stallId, required this.startMin, required this.capacity, required this.booked, this.open = true, String? date})
      : date = date ?? ymd(DateTime.now());

  final String id;
  final String campusId;
  final String stallId;
  final int startMin; // minutes since midnight
  final String date; // yyyymmdd local — windows are per-day so counters reset naturally
  int capacity;
  int booked;
  bool open;

  int get remaining => (capacity - booked).clamp(0, capacity);
  bool get full => remaining <= 0;

  String get startLabel => _fmt(startMin);
  String get endLabel => _fmt(startMin + 10);
  String get label => '$startLabel – $endLabel';

  static String _fmt(int min) {
    var h = min ~/ 60;
    final m = min % 60;
    final pm = h >= 12;
    var hh = h % 12;
    if (hh == 0) hh = 12;
    return '$hh:${m.toString().padLeft(2, '0')} ${pm ? 'PM' : 'AM'}';
  }

  Map<String, dynamic> toMap() => {'id': id, 'campusId': campusId, 'stallId': stallId, 'startMin': startMin, 'capacity': capacity, 'booked': booked, 'open': open, 'date': date};
  factory Slot.fromMap(Map m) => Slot(id: m['id'], campusId: m['campusId'], stallId: m['stallId'], startMin: m['startMin'], capacity: m['capacity'] ?? 20, booked: m['booked'] ?? 0, open: m['open'] ?? true, date: m['date'] ?? '');
}

class OrderItem {
  OrderItem({required this.dishId, required this.name, required this.qty, required this.price});
  final String dishId;
  final String name;
  final int qty;
  final double price;
  double get total => price * qty;
  Map<String, dynamic> toMap() => {'dishId': dishId, 'name': name, 'qty': qty, 'price': price};
  factory OrderItem.fromMap(Map m) => OrderItem(dishId: m['dishId'] ?? '', name: m['name'] ?? '', qty: m['qty'] ?? 1, price: (m['price'] as num?)?.toDouble() ?? 0);
}

class OrderRec {
  OrderRec({
    required this.id,
    required this.orderNo,
    required this.campusId,
    required this.stallId,
    required this.stallName,
    required this.customerId,
    required this.customerName,
    required this.customerSchoolId,
    required this.items,
    required this.total,
    required this.slotId,
    required this.slotLabel,
    required this.payment,
    required this.payRef,
    required this.status,
    required this.placedAt,
    this.claimedAt,
    this.claimedBy,
  });

  final String id;
  final String orderNo; // GG-0001
  final String campusId;
  final String stallId;
  final String stallName;
  final String customerId;
  final String customerName;
  final String customerSchoolId;
  final List<OrderItem> items;
  final double total;
  final String slotId;
  final String slotLabel;
  final PayMethod payment;
  final String payRef;
  OrderStatus status;
  final DateTime placedAt;
  DateTime? claimedAt;
  String? claimedBy;

  String get itemsSummary => items.map((i) => '${i.qty} ${i.name}').join(', ');

  Map<String, dynamic> toMap() => {
        'id': id,
        'orderNo': orderNo,
        'campusId': campusId,
        'stallId': stallId,
        'stallName': stallName,
        'customerId': customerId,
        'customerName': customerName,
        'customerSchoolId': customerSchoolId,
        'items': items.map((i) => i.toMap()).toList(),
        'total': total,
        'slotId': slotId,
        'slotLabel': slotLabel,
        'payment': payment.name,
        'payRef': payRef,
        'status': status.name,
        'placedAt': placedAt.toIso8601String(),
        'claimedAt': claimedAt?.toIso8601String(),
        'claimedBy': claimedBy,
      };

  factory OrderRec.fromMap(Map m) => OrderRec(
        id: m['id'],
        orderNo: m['orderNo'] ?? 'GG-0000',
        campusId: m['campusId'],
        stallId: m['stallId'],
        stallName: m['stallName'] ?? '',
        customerId: m['customerId'] ?? '',
        customerName: m['customerName'] ?? '',
        customerSchoolId: m['customerSchoolId'] ?? '—',
        items: (m['items'] as List? ?? []).map((e) => OrderItem.fromMap(Map<String, dynamic>.from(e))).toList(),
        total: (m['total'] as num?)?.toDouble() ?? 0,
        slotId: m['slotId'] ?? '',
        slotLabel: m['slotLabel'] ?? '',
        payment: PayMethod.values.firstWhere((p) => p.name == m['payment'], orElse: () => PayMethod.counter),
        payRef: m['payRef'] ?? '',
        status: OrderStatus.values.firstWhere((s) => s.name == m['status'], orElse: () => OrderStatus.preparing),
        placedAt: DateTime.tryParse(m['placedAt'] ?? '') ?? DateTime.now(),
        claimedAt: DateTime.tryParse(m['claimedAt'] ?? ''),
        claimedBy: m['claimedBy'],
      );
}

class Payout {
  Payout({required this.id, required this.campusId, required this.stallId, required this.stallName, required this.periodLabel, required this.gross, required this.shareRate, required this.share, required this.net, required this.status, this.paidAt});

  final String id;
  final String campusId;
  final String stallId;
  final String stallName;
  final String periodLabel;
  final double gross;
  final double shareRate;
  final double share;
  final double net;
  PayoutStatus status;
  DateTime? paidAt;

  Map<String, dynamic> toMap() => {'id': id, 'campusId': campusId, 'stallId': stallId, 'stallName': stallName, 'periodLabel': periodLabel, 'gross': gross, 'shareRate': shareRate, 'share': share, 'net': net, 'status': status.name, 'paidAt': paidAt?.toIso8601String()};
  factory Payout.fromMap(Map m) => Payout(id: m['id'], campusId: m['campusId'], stallId: m['stallId'], stallName: m['stallName'] ?? '', periodLabel: m['periodLabel'] ?? '', gross: (m['gross'] as num?)?.toDouble() ?? 0, shareRate: (m['shareRate'] as num?)?.toDouble() ?? 0.05, share: (m['share'] as num?)?.toDouble() ?? 0, net: (m['net'] as num?)?.toDouble() ?? 0, status: PayoutStatus.values.firstWhere((p) => p.name == m['status'], orElse: () => PayoutStatus.pending), paidAt: DateTime.tryParse(m['paidAt'] ?? ''));
}

class Note {
  Note({required this.id, required this.campusId, required this.userId, required this.title, required this.body, required this.at, this.read = false, this.kind = 'info'});

  final String id;
  final String campusId;
  final String userId;
  final String title;
  final String body;
  final DateTime at;
  bool read;
  final String kind; // info | success | warning | danger

  Map<String, dynamic> toMap() => {'id': id, 'campusId': campusId, 'userId': userId, 'title': title, 'body': body, 'at': at.toIso8601String(), 'read': read, 'kind': kind};
  factory Note.fromMap(Map m) => Note(id: m['id'], campusId: m['campusId'], userId: m['userId'] ?? '', title: m['title'] ?? '', body: m['body'] ?? '', at: DateTime.tryParse(m['at'] ?? '') ?? DateTime.now(), read: m['read'] ?? false, kind: m['kind'] ?? 'info');
}

// ---------------------------------------------------------------- database
class Database {
  Database._();

  static FirebaseFirestore? _dbInstance;
  static FirebaseAuth? _authInstance;

  /// Test-injectable handles. Production uses the real SDKs; tests use fakes.
  static FirebaseAuth get appAuth => _authInstance ?? FirebaseAuth.instance;
  static FirebaseFirestore get appFirestore => _dbInstance ?? FirebaseFirestore.instance;

  static FirebaseFirestore get _db => appFirestore;
  static FirebaseAuth get _auth => appAuth;

  static Campus? _campus;
  static final List<Account> _accounts = [];
  static final List<Stall> _stalls = [];
  static final List<Dish> _dishes = [];
  static final List<Slot> _slots = [];
  static final List<OrderRec> _orders = [];
  static final List<Payout> _payouts = [];
  static final List<Note> _notifications = [];
  static late FirebaseOptions _options;

  static bool _ready = false;
  static bool get ready => _ready;

  static const builtInAdminEmail = 'admin@gmail.com';
  static const builtInAdminPassword = 'Grab&Go#Admin2026';
  static const builtInCampusId = 'campus_batstateu';

  /// Subscriptions bound post-login (private collections), cancelled on sign-out.
  static final List<StreamSubscription<QuerySnapshot<Map<String, dynamic>>>> _sessionSubs = [];
  static Account? _seedAccountCache;

  /// Called whenever any collection emits a new snapshot.
  static void Function()? onChanged;

  static void _fireChanged() {
    _ready = true;
    onChanged?.call();
  }

  /// Create (or sign in as) an Auth user without switching the current session.
  /// In tests the caller passes fakes; in production we spin up a secondary app.
  static Future<UserCredential> _authSecondary(String email, String password) async {
    if (_dbInstance != null) {
      // Tests inject fakes. Create fresh users here but don't leave a session behind.
      try {
        final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
        await _auth.signOut();
        return cred;
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          final cred = await _auth.signInWithEmailAndPassword(email: email, password: password);
          await _auth.signOut();
          return cred;
        }
        rethrow;
      }
    }
    final secondary = await Firebase.initializeApp(name: 'Secondary_${DateTime.now().microsecondsSinceEpoch}', options: _options);
    final auth = FirebaseAuth.instanceFor(app: secondary);
    try {
      return await auth.createUserWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        return auth.signInWithEmailAndPassword(email: email, password: password);
      }
      rethrow;
    } finally {
      await secondary.delete();
    }
  }
  // ---------------- init & seeding ----------------
  static Future<void> init({FirebaseFirestore? firestore, FirebaseAuth? auth, FirebaseOptions? options}) async {
    // Already initialized (tests call init with fakes, then main/AppState re-calls it).
    if (_ready) return;
    _dbInstance = firestore;
    _authInstance = auth;
    _options = options ?? (kIsWeb || defaultTargetPlatform == TargetPlatform.android ? DefaultFirebaseOptions.currentPlatform : const FirebaseOptions(apiKey: 'fake', appId: 'fake', messagingSenderId: 'fake', projectId: 'fake', storageBucket: 'fake'));

    try {
      await _seedIfEmpty();
    } catch (e, stack) {
      Error.throwWithStackTrace(StateError('SEED: $e'), stack);
    }

    try {
      _campus = Campus.fromMap(Map<String, dynamic>.from((await _db.collection('campuses').doc(builtInCampusId).get()).data() ?? {}));
    } catch (e, stack) {
      Error.throwWithStackTrace(StateError('CAMPUSLOAD: $e'), stack);
    }

    // Live listeners for public pre-login data: campus info, stalls, menu, pickup slots.
    // (These are never unsubscribed — the app lives for the whole session.)
    void bind<T>(Query<Map<String, dynamic>> query, T Function(Map<String, dynamic>) parse, void Function(List<T>) store, int Function(T a, T b) cmp) {
      query.snapshots().listen((snap) {
        final list = snap.docs.map((d) => parse(d.data())).toList();
        list.sort(cmp);
        store(list);
        _fireChanged();
      });
    }

    try {
      bind<Campus>(_db.collection('campuses').where('id', isEqualTo: builtInCampusId), Campus.fromMap, (list) { _campus = list.isNotEmpty ? list.first : null; }, (a, b) => 0);
      bind<Stall>(_db.collection('stalls').where('campusId', isEqualTo: builtInCampusId), Stall.fromMap, (list) { _stalls..clear()..addAll(list); }, (a, b) => a.createdAt.compareTo(b.createdAt));
      bind<Dish>(_db.collection('dishes').where('campusId', isEqualTo: builtInCampusId), Dish.fromMap, (list) { _dishes..clear()..addAll(list); }, (a, b) => (b.isNew ? 1 : 0).compareTo(a.isNew ? 1 : 0));
      bind<Slot>(_db.collection('slots').where('campusId', isEqualTo: builtInCampusId), Slot.fromMap, (list) { _slots..clear()..addAll(list); }, (a, b) => a.startMin.compareTo(b.startMin));
    } catch (e, stack) {
      Error.throwWithStackTrace(StateError('BIND: $e'), stack);
    }

    // Wait for the first snapshot of each public collection so the UI never renders empty-then-full.
    try {
      await Future.wait([
        _db.collection('campuses').doc(builtInCampusId).snapshots().first,
        _db.collection('stalls').where('campusId', isEqualTo: builtInCampusId).snapshots().first,
        _db.collection('dishes').where('campusId', isEqualTo: builtInCampusId).snapshots().first,
        _db.collection('slots').where('campusId', isEqualTo: builtInCampusId).snapshots().first,
      ]).timeout(const Duration(seconds: 8), onTimeout: () => throw StateError('WAIT: timed out waiting for public data (check your internet connection and Firestore rules)'));
    } catch (e, stack) {
      Error.throwWithStackTrace(StateError('WAIT: $e'), stack);
    }

    // Slot windows are generated/closed after sign-in (signed-out devices can't write) —
    // bindSessionCollections does that. Nothing signed-out here.
    _ready = true;
  }

  /// Bind private collections (accounts, orders, payouts, notifications) after authentication —
  /// those are unreadable pre-login by design. Binding is role-aware so Firestore rules can
  /// scope reads: main admins see the whole campus, stall admins their stall, customers their own orders.
  static Future<void> bindSessionCollections() async {
    // Always rebind against the CURRENT auth state — a pre-login no-op must not stick.
    await unbindSessionCollections();
    if (_seedAccountCache != null && !_accounts.any((a) => a.id == _seedAccountCache!.id)) _accounts.add(_seedAccountCache!);

    final uid = _auth.currentUser?.uid;
    Map<String, dynamic>? ownDoc;
    if (uid != null) {
      try {
        ownDoc = (await _db.collection('accounts').doc(uid).get()).data();
      } catch (_) {}
    }
    final role = ownDoc?['role'] as String?;
    final stallId = ownDoc?['stallId'] as String?;
    final isMain = role == 'mainAdmin';
    final isStall = role == 'stallAdmin';
    // Everyone keeps at least their own account doc for role lookups.
    final ownAccount = ownDoc != null ? Account.fromMap(Map<String, dynamic>.from(ownDoc)) : null;
    if (ownAccount != null) _accounts.add(ownAccount);

    void bind<T>(Query<Map<String, dynamic>> query, T Function(Map<String, dynamic>) parse, void Function(List<T>) store, int Function(T a, T b) cmp) {
      _sessionSubs.add(query.snapshots().listen((snap) {
        final list = snap.docs.map((d) => parse(d.data())).toList();
        list.sort(cmp);
        store(list);
        _fireChanged();
      }));
    }

    void storeAccounts(List<Account> list) {
      _accounts..clear()..addAll(list);
      // Campus query covers everyone for main admins; make sure our own doc stays present either way.
      if (ownAccount != null && !_accounts.any((a) => a.id == ownAccount.id)) _accounts.add(ownAccount);
    }

    int accountSort(Account a, Account b) => a.createdAt.compareTo(b.createdAt);
    int orderSort(OrderRec a, OrderRec b) => b.placedAt.compareTo(a.placedAt);
    int payoutSort(Payout a, Payout b) => b.periodLabel.compareTo(a.periodLabel);
    int noteSort(Note a, Note b) => b.at.compareTo(a.at);

    try {
      if (isMain) {
        bind<Account>(_db.collection('accounts').where('campusId', isEqualTo: builtInCampusId), Account.fromMap, storeAccounts, accountSort);
        bind<OrderRec>(_db.collection('orders').where('campusId', isEqualTo: builtInCampusId), OrderRec.fromMap, (list) { _orders..clear()..addAll(list); }, orderSort);
        bind<Payout>(_db.collection('payouts').where('campusId', isEqualTo: builtInCampusId), Payout.fromMap, (list) { _payouts..clear()..addAll(list); }, payoutSort);
      } else if (isStall && stallId != null) {
        bind<OrderRec>(_db.collection('orders').where('stallId', isEqualTo: stallId), OrderRec.fromMap, (list) { _orders..clear()..addAll(list); }, orderSort);
        bind<Payout>(_db.collection('payouts').where('stallId', isEqualTo: stallId), Payout.fromMap, (list) { _payouts..clear()..addAll(list); }, payoutSort);
      } else if (uid != null) {
        bind<OrderRec>(_db.collection('orders').where('customerId', isEqualTo: uid), OrderRec.fromMap, (list) { _orders..clear()..addAll(list); }, orderSort);
      }
      if (uid != null) {
        bind<Note>(_db.collection('notifications').where('userId', isEqualTo: uid), Note.fromMap, (list) { _notifications..clear()..addAll(list); }, noteSort);
      }
    } catch (e, stack) {
      Error.throwWithStackTrace(StateError('BIND_SESSION: $e'), stack);
    }

    // Refresh today's pickup windows for every active stall + close windows that started.
    // Runs on ANY signed-in device (customers included) so windows exist even without staff online.
    try {
      final nowMin = DateTime.now().hour * 60 + DateTime.now().minute;
      for (final stall in List.of(_stalls.where((s) => s.status == StallStatus.active))) {
        await _ensureSlots(campusId: builtInCampusId, stallId: stall.id);
      }
      for (final slot in List.of(_slots.where((s) => s.date == ymd(DateTime.now()) && s.startMin <= nowMin && s.open))) {
        await _db.collection('slots').doc(slot.id).update({'open': false});
      }
    } catch (_) {
      // Best effort — staff devices retry at their next session bind.
    }

    try {
      final waits = <Future<QuerySnapshot<Map<String, dynamic>>>>[];
      if (isMain) {
        waits.add(_db.collection('accounts').where('campusId', isEqualTo: builtInCampusId).snapshots().first);
        waits.add(_db.collection('orders').where('campusId', isEqualTo: builtInCampusId).snapshots().first);
        waits.add(_db.collection('payouts').where('campusId', isEqualTo: builtInCampusId).snapshots().first);
      } else if (isStall && stallId != null) {
        waits.add(_db.collection('orders').where('stallId', isEqualTo: stallId).snapshots().first);
        waits.add(_db.collection('payouts').where('stallId', isEqualTo: stallId).snapshots().first);
      } else if (uid != null) {
        waits.add(_db.collection('orders').where('customerId', isEqualTo: uid).snapshots().first);
      }
      if (uid != null) waits.add(_db.collection('notifications').where('userId', isEqualTo: uid).snapshots().first);
      if (waits.isEmpty) return;
      await Future.wait(waits).timeout(const Duration(seconds: 8), onTimeout: () => throw StateError('WAIT_SESSION: timed out waiting for private data (check your internet connection and Firestore rules)'));
    } catch (e, stack) {
      Error.throwWithStackTrace(StateError('WAIT_SESSION: $e'), stack);
    }
  }

  /// Sign-out: cancel private listeners and clear their caches.
  static Future<void> unbindSessionCollections() async {
    // Copy — cancelling a listener can re-enter this function under the fakes.
    for (final s in List.of(_sessionSubs)) {
      await s.cancel();
    }
    _sessionSubs.clear();
    _accounts.clear();
    _orders.clear();
    _payouts.clear();
    _notifications.clear();
  }

  static Future<void> _seedIfEmpty() async {
    final firestore = _db;

    // ALWAYS repair/ensure the campus + built-in admin exist (idempotent).
    // Past crashed runs left the sentinel set without creating the admin profile —
    // which permanently blocked signed-out writes and broke the rules' role checks.
    final seedAuth = (_dbInstance != null) ? _auth : FirebaseAuth.instance;

    // 1. Sign in (or create) the built-in admin first — the security rules
    // specifically allow this one email through to finish seeding.
    String uid;
    try {
      final cred = await seedAuth.signInWithEmailAndPassword(email: builtInAdminEmail, password: builtInAdminPassword);
      uid = cred.user!.uid;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'invalid-credential' || e.code == 'wrong-password') {
        // First-time bootstrap: create the built-in admin Auth user.
        final cred = await seedAuth.createUserWithEmailAndPassword(email: builtInAdminEmail, password: builtInAdminPassword);
        uid = cred.user!.uid;
      } else {
        rethrow;
      }
    }

    // 2. Campus doc (merge — keeps existing fields).
    await firestore.collection('campuses').doc(builtInCampusId).set(
      Campus(id: builtInCampusId, name: 'Batangas State University', shortName: 'BatStateU', domain: 'g.batstate-u.edu.ph', idPattern: r'^\d{2}-\d{5}$', idHint: '23-12345').toMap(),
      SetOptions(merge: true),
    );

    // 3. Built-in admin profile doc
    final builtinAdmin = Account(
      id: uid,
      campusId: builtInCampusId,
      name: 'Canteen Office Admin',
      email: builtInAdminEmail,
      role: AccountRole.mainAdmin,
      type: AccountType.employee,
      schoolId: 'ADMIN-001',
      createdAt: DateTime(2024, 8, 1),
      colorIndex: 2,
    );
    await firestore.collection('accounts').doc(uid).set(builtinAdmin.toMap(), SetOptions(merge: true));
    // Make sure the accounts cache isn't empty pre-login (tests + bootstrap role lookups).
    _seedAccountCache = builtinAdmin;
    if (!_accounts.any((a) => a.id == uid)) _accounts.add(builtinAdmin);

    // 4. Mark seeded (rules: allows pre-login reads once this exists)
    await firestore.collection('meta').doc(builtInCampusId).set({'builtInSeeded': true}, SetOptions(merge: true));

    // Sign back out so nobody is silently logged in on a shared device.
    try {
      await seedAuth.signOut();
    } catch (_) {}
  }

  static Campus? campus(String id) => _campus;
  static List<Campus> campusList() => _campus == null ? const [] : [_campus!];
  static Campus defaultCampus() => _campus!;

  // ---------------- session meta ----------------
  static String? sessionUserId() => null; // Firebase Auth owns the session
  static Future<void> setSession(String? id) async {} // no-op: Firebase Auth handles sign-out
  static int? lastRoleIndex() => null;
  static Future<void> setLastRoleIndex(int i) async {}

  // ---------------- accounts ----------------
  static Account? accountById(String id, {String? campusId}) {
    for (final a in _accounts) {
      if (a.id == id) return a;
    }
    return null;
  }

  static Account? accountByEmail(String email, {required String campusId}) {
    final norm = email.trim().toLowerCase();
    for (final a in _accounts) {
      if (a.email.toLowerCase() == norm) return a;
    }
    return null;
  }

  /// Direct authenticated lookup of an account by email — used as a sign-in fallback
  /// when the Auth uid doesn't match the stored doc id. Rules allow reading your own doc.
  static Future<Account?> findAccountByEmail(String email) async {
    final e = email.trim().toLowerCase();
    try {
      final snap = await _db.collection('accounts').where('email', isEqualTo: e).limit(1).get();
      if (snap.docs.isEmpty) return null;
      final doc = snap.docs.first;
      final account = Account.fromMap(Map<String, dynamic>.from(doc.data()));
      if (!_accounts.any((a) => a.id == account.id)) _accounts.add(account);
      return account;
    } catch (_) {
      return null;
    }
  }

  static List<Account> accounts(String campusId) => List.of(_accounts);

  /// Create an account backed by Firebase Auth — used by register, admin add-account, and approvals.
  static Future<Account> _createAccountDoc({
    required String email,
    required String password,
    required AccountRole role,
    required AccountType type,
    required String name,
    required String schoolId,
    String? stallId,
    int colorIndex = 0,
    bool signInNewUser = false,
  }) async {
    // Don't sign out the current admin — creation goes through a secondary Auth instance.
    final cred = await _authSecondary(email.trim().toLowerCase(), password);
    final uid = cred.user!.uid;

    // Self-registration: make sure the default session is the NEW user, so the
    // account doc is written authenticated as its owner (rules can require it).
    if (signInNewUser) {
      await _auth.signInWithEmailAndPassword(email: email.trim().toLowerCase(), password: password);
    }

    final account = Account(
      id: uid,
      campusId: builtInCampusId,
      name: name.trim(),
      email: email.trim().toLowerCase(),
      role: role,
      type: type,
      schoolId: schoolId.trim().isEmpty ? '—' : schoolId.trim(),
      stallId: stallId,
      active: true,
      createdAt: DateTime.now(),
      colorIndex: colorIndex,
    );
    await _db.collection('accounts').doc(uid).set(account.toMap());
    return account;
  }

  static Future<Account> createAccount({
    required String campusId,
    required String name,
    required String email,
    required String password,
    required AccountRole role,
    AccountType type = AccountType.student,
    String schoolId = '—',
    String? stallId,
    bool active = true,
    bool signInNewUser = false,
  }) async {
    // Temporary passwords (admin flows) — the caller chooses.
    if (!active) return accountByEmail(email, campusId: campusId)!; // sync holder; inactive accounts can't sign in anyway
    return _createAccountDoc(email: email, password: password, role: role, type: type, name: name, schoolId: schoolId, stallId: stallId, colorIndex: DateTime.now().millisecond % 6, signInNewUser: signInNewUser);
  }

  static Future<Account?> updateAccount(Account account) async {
    await _db.collection('accounts').doc(account.id).update(account.toMap());
    return accountById(account.id, campusId: account.campusId);
  }

  /// Admin reset → send a Firebase password-reset email.
  static Future<String?> resetPassword(String accountId, {required String campusId, required String newPassword}) async {
    final account = accountById(accountId, campusId: campusId);
    if (account == null) return 'Account not found.';
    try {
      await _auth.sendPasswordResetEmail(email: account.email);
      return null;
    } catch (e) {
      return 'Could not send reset email: $e';
    }
  }

  static Future<void> setAccountActive(String accountId, {required bool active}) async {
    final account = accountById(accountId);
    if (account == null) return;
    await updateAccount(account.copyWith(active: active));
  }

  static Future<String?> deleteAccount(String accountId, {required String campusId, required String currentUserId}) async {
    if (accountId == currentUserId) return 'You cannot remove your own account while signed in.';
    final account = accountById(accountId, campusId: campusId);
    if (account == null) return 'Account not found.';
    await _db.collection('accounts').doc(accountId).delete();
    // Auth user remains but can no longer sign in — profile doc gone.
    return null;
  }

  // ---------------- stalls ----------------
  static List<Stall> stalls(String campusId, {StallStatus? status}) {
    final out = List<Stall>.of(_stalls);
    return status == null ? out : out.where((s) => s.status == status).toList();
  }

  static Stall? stallById(String id) {
    for (final s in _stalls) {
      if (s.id == id) return s;
    }
    return null;
  }

  static Stall? stallByName(String name, {String? exceptId}) {
    for (final s in _stalls) {
      if (s.name.trim().toLowerCase() == name.trim().toLowerCase() && s.id != exceptId) return s;
    }
    return null;
  }

  static Future<Stall> createStall({
    required String campusId,
    required String name,
    required String blurb,
    required List<String> categories,
    required String personName,
    required String adminEmail,
    StallStatus status = StallStatus.active,
  }) async {
    final id = 'stall_${DateTime.now().microsecondsSinceEpoch}';
    final stall = Stall(id: id, campusId: campusId, name: name.trim(), blurb: blurb.trim(), categories: categories, personName: personName.trim(), adminEmail: adminEmail.trim().toLowerCase(), status: status, createdAt: DateTime.now(), colorIndex: DateTime.now().millisecond % 6, iconIndex: DateTime.now().millisecond % 6);
    await _db.collection('stalls').doc(id).set(stall.toMap());
    await _ensureSlots(campusId: campusId, stallId: stall.id);
    return stall;
  }

  static Future<void> updateStall(Stall stall) async {
    await _db.collection('stalls').doc(stall.id).update(stall.toMap());
  }

  /// Partial update of ONLY the storefront photo — matches the stall-admin rules.
  static Future<void> updateStallPhoto({required String stallId, required String? photo}) async {
    await _db.collection('stalls').doc(stallId).update({'photo': photo});
  }

  /// Partial update of ONLY the pickup schedule + window limit.
  static Future<void> updateStallSchedule({required String stallId, required int openMin, required int closeMin, required int slotCapacity}) async {
    await _db.collection('stalls').doc(stallId).update({'openMin': openMin, 'closeMin': closeMin, 'slotCapacity': slotCapacity});
  }

  /// Public wrapper that returns the error instead of swallowing it — powers the "Retry" button.
  static Future<String?> ensureSlotsDetailed({required String campusId, required String stallId}) async {
    try {
      await _ensureSlots(campusId: campusId, stallId: stallId);
      return null;
    } catch (e) {
      return e.toString().replaceAll('cloud_firestore/', '');
    }
  }

  /// Standing windows for this stall's OWN operating hours (7 AM–7 PM by default),
  /// 10-minute slots, scoped per day so counters reset naturally, with the stall's
  /// own per-window order limit ("store limit"). Generated on any sign-in.
  /// New windows are created with booked/open present; existing ones are merged
  /// WITHOUT booked/open so live counters are never reset.
  static Future<void> _ensureSlots({required String campusId, required String stallId}) async {
    final stall = stallById(stallId);
    final openMin = stall?.openMin ?? 7 * 60;
    final closeMin = stall?.closeMin ?? 19 * 60;
    final capacity = stall?.slotCapacity ?? 20;

    final now = DateTime.now();
    final today = ymd(now);

    // Find which of today's windows already exist (one query, not 72 reads).
    // Docs missing `booked` can only exist from before self-describing windows —
    // a successful order always writes booked, so those docs have no real counters to lose.
    final existing = <String>{};
    final missingCounters = <String>{};
    final openById = <String, bool>{};
    final capacityById = <String, int>{};
    try {
      final snap = await _db.collection('slots').where('stallId', isEqualTo: stallId).where('date', isEqualTo: today).get();
      for (final d in snap.docs) {
        existing.add(d.id);
        final data = d.data();
        openById[d.id] = (data['open'] as bool?) ?? true;
        capacityById[d.id] = (data['capacity'] as int?) ?? capacity;
        if (!data.containsKey('booked')) missingCounters.add(d.id);
      }
    } catch (_) {
      // If the lookup fails, treat everything as new — booked/open are written either way.
    }

    final batch = _db.batch();
    for (var start = openMin; start < closeMin; start += 10) {
      final id = 'slot_${stallId}_${today}_$start';
      if (missingCounters.contains(id)) {
        // Repair a legacy doc (no orders possible against it).
        batch.set(_db.collection('slots').doc(id), {
          'id': id,
          'campusId': campusId,
          'stallId': stallId,
          'startMin': start,
          'capacity': capacityById[id] ?? capacity,
          'booked': 0,
          'open': openById[id] ?? true,
          'date': today,
        });
      } else if (existing.contains(id)) {
        // Merge ONLY immutable fields — live counters/open must survive restarts.
        batch.set(_db.collection('slots').doc(id), {
          'id': id,
          'campusId': campusId,
          'stallId': stallId,
          'startMin': start,
          'capacity': capacity,
          'date': today,
        }, SetOptions(merge: true));
      } else {
        // Self-describing from birth — rules compare against booked/open.
        batch.set(_db.collection('slots').doc(id), {
          'id': id,
          'campusId': campusId,
          'stallId': stallId,
          'startMin': start,
          'capacity': capacity,
          'booked': 0,
          'open': true,
          'date': today,
        });
      }
    }
    await batch.commit();
  }

  // ---------------- slots ----------------
  /// Today's windows for a stall, in order. Legacy undated docs (date == '') are ignored.
  static List<Slot> slots({required String campusId, required String stallId}) {
    final today = ymd(DateTime.now());
    return _slots.where((s) => s.stallId == stallId && s.date == today).toList()..sort((a, b) => a.startMin.compareTo(b.startMin));
  }

  static Future<void> updateSlot(Slot slot) async {
    await _db.collection('slots').doc(slot.id).update(slot.toMap());
  }

  // ---------------- dishes ----------------
  static List<Dish> dishes(String campusId, {String? stallId}) {
    final out = stallId == null ? List<Dish>.of(_dishes) : _dishes.where((d) => d.stallId == stallId).toList();
    return out;
  }

  static Dish? dishById(String id) {
    for (final d in _dishes) {
      if (d.id == id) return d;
    }
    return null;
  }

  static Dish? dishByName(String name, {String? stallId, String? exceptId}) {
    for (final d in _dishes) {
      if (d.name.trim().toLowerCase() == name.trim().toLowerCase() && d.id != exceptId && (stallId == null || d.stallId == stallId)) return d;
    }
    return null;
  }

  static Future<Dish> createDish({
    required String campusId,
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
    final id = 'dish_${DateTime.now().microsecondsSinceEpoch}';
    final dish = Dish(id: id, campusId: campusId, stallId: stallId, name: name.trim(), description: description.trim(), price: price, servingsLeft: servings, initialStock: servings, category: category, liveTray: liveTray, isNew: true, createdAt: DateTime.now(), iconIndex: iconIndex ?? DateTime.now().millisecond % 8, colorIndex: colorIndex ?? DateTime.now().millisecond % 8, photo: photo);
    await _db.collection('dishes').doc(id).set(dish.toMap());
    return dish;
  }

  static Future<void> updateDish(Dish dish) async {
    await _db.collection('dishes').doc(dish.id).update(dish.toMap());
  }

  static Future<void> deleteDish(String id) async => _db.collection('dishes').doc(id).delete();

  // ---------------- orders ----------------
  static List<OrderRec> orders(String campusId, {String? stallId, String? customerId}) {
    final out = List<OrderRec>.of(_orders);
    return out.where((o) => (stallId == null || o.stallId == stallId) && (customerId == null || o.customerId == customerId)).toList();
  }

  static OrderRec? orderById(String id, {String? campusId}) {
    for (final o in _orders) {
      if (o.id == id) return o;
    }
    return null;
  }

  static OrderRec? orderByNo(String orderNo, {String? campusId}) {
    final norm = orderNo.trim().toUpperCase().replaceAll('#', '');
    for (final o in _orders) {
      if (o.orderNo.toUpperCase() == norm) return o;
    }
    return null;
  }

  static Future<OrderRec> placeOrder({
    required String campusId,
    required Account customer,
    required Stall stall,
    required List<OrderItem> items,
    required Slot slot,
    required PayMethod method,
    required String payRef,
  }) async {
    final total = items.fold<double>(0, (a, i) => a + i.total);
    final id = 'order_${DateTime.now().microsecondsSinceEpoch}';
    final counterRef = _db.collection('counters').doc(campusId);
    final orderRef = _db.collection('orders').doc(id);
    final slotRef = _db.collection('slots').doc(slot.id);
    final dishRefs = [for (final i in items) _db.collection('dishes').doc(i.dishId)];

    return _db.runTransaction((tx) async {
      // READ phase first — Firestore requires all reads before any writes.
      final counterSnap = await tx.get(counterRef);
      final dishSnaps = [for (final (i, _) in items.indexed) await tx.get(dishRefs[i])];
      final slotSnap = await tx.get(slotRef);

      // WRITE phase
      final counter = (counterSnap.data()?['order'] as int? ?? 0) + 1;
      tx.set(counterRef, {'order': counter}, SetOptions(merge: true));

      for (var i = 0; i < items.length; i++) {
        final d = Dish.fromMap(Map<String, dynamic>.from(dishSnaps[i].data() ?? {}));
        tx.update(dishRefs[i], {'servingsLeft': (d.servingsLeft - items[i].qty).clamp(0, 9999)});
      }

      final s = Slot.fromMap(Map<String, dynamic>.from(slotSnap.data() ?? {}));
      tx.update(slotRef, {'booked': (s.booked + 1).clamp(0, s.capacity)});

      // Write the order.
      final order = OrderRec(
        id: id,
        orderNo: 'GG-${counter.toString().padLeft(4, '0')}',
        campusId: campusId,
        stallId: stall.id,
        stallName: stall.name,
        customerId: customer.id,
        customerName: customer.name,
        customerSchoolId: customer.schoolId,
        items: items,
        total: total,
        slotId: slot.id,
        slotLabel: slot.label,
        payment: method,
        payRef: payRef,
        status: OrderStatus.preparing,
        placedAt: DateTime.now(),
      );
      tx.set(orderRef, order.toMap());
      return order;
    });
  }

  static Future<void> updateOrderStatus(OrderRec order, OrderStatus status, {String? claimedBy}) async {
    await _db.collection('orders').doc(order.id).update({
      'status': status.name,
      if (status == OrderStatus.claimed) ...{'claimedAt': DateTime.now().toIso8601String(), 'claimedBy': claimedBy ?? 'Stall admin'},
    });
  }

  /// True if the order's pickup window + 10-minute grace period has fully passed
  /// and it was never claimed (preparing/ready only).
  static bool isLapsed(OrderRec o) {
    if (o.status != OrderStatus.preparing && o.status != OrderStatus.ready) return false;
    final start = slotStartFor(o);
    if (start == null) return false;
    return DateTime.now().isAfter(start.add(const Duration(minutes: 10)).add(const Duration(minutes: 10)));
  }

  /// Release unclaimed orders whose slot + 10-minute grace has passed.
  /// Each affected customer gets an "Order expired" notification.
  static Future<int> releaseStaleOrders(String campusId) async {
    var released = 0;
    for (final o in List<OrderRec>.of(_orders)) {
      if (!isLapsed(o)) continue;
      await updateOrderStatus(o, OrderStatus.released);
      try {
        await pushNote(
          campusId: campusId,
          userId: o.customerId,
          title: 'Order expired',
          body: '#${o.orderNo} was not picked up within the 10-minute grace period, so it was released.',
          kind: 'warning',
        );
      } catch (_) {}
      released++;
    }
    return released;
  }

  static DateTime? slotStartFor(OrderRec o) {
    final parts = o.slotId.split('_');
    if (parts.length < 3) return null;
    final min = int.tryParse(parts.last);
    if (min == null) return null;
    // New ids carry a yyyymmdd segment: slot_<stallId>_<yyyymmdd>_<startMin>
    if (parts.length >= 4) {
      final raw = parts[parts.length - 2];
      if (raw.length == 8 && int.tryParse(raw) != null) {
        final y = int.parse(raw.substring(0, 4));
        final mo = int.parse(raw.substring(4, 6));
        final d = int.parse(raw.substring(6, 8));
        return DateTime(y, mo, d, min ~/ 60, min % 60);
      }
    }
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, min ~/ 60, min % 60);
  }

  // ---------------- payouts ----------------
  static List<Payout> payouts(String campusId, {String? stallId}) {
    final out = stallId == null ? List<Payout>.of(_payouts) : _payouts.where((p) => p.stallId == stallId).toList();
    return out;
  }

  static Future<void> updatePayout(Payout payout) async => _db.collection('payouts').doc(payout.id).update(payout.toMap());

  static Future<Payout> createPayout({required String campusId, required Stall stall, required String periodLabel, required double gross}) async {
    const rate = 0.05;
    final id = 'payout_${DateTime.now().microsecondsSinceEpoch}';
    final payout = Payout(id: id, campusId: campusId, stallId: stall.id, stallName: stall.name, periodLabel: periodLabel, gross: gross, shareRate: rate, share: gross * rate, net: gross - gross * rate, status: PayoutStatus.pending);
    await _db.collection('payouts').doc(id).set(payout.toMap());
    return payout;
  }

  // ---------------- notifications ----------------
  static List<Note> notes(String campusId, String userId) => _notifications.where((n) => n.userId == userId).toList();

  static Future<void> pushNote({required String campusId, required String userId, required String title, required String body, required String kind}) async {
    final id = 'note_${DateTime.now().microsecondsSinceEpoch}';
    await _db.collection('notifications').doc(id).set(Note(id: id, campusId: campusId, userId: userId, title: title, body: body, at: DateTime.now(), kind: kind).toMap());
  }

  static Future<void> markNotesRead(String campusId, String userId) async {
    final batch = _db.batch();
    for (final n in notes(campusId, userId)) {
      if (!n.read) {
        batch.update(_db.collection('notifications').doc(n.id), {'read': true});
      }
    }
    await batch.commit();
  }

  // ---------------- admin data control ----------------
  static Future<void> clearEverythingExceptCampus() async {
    final keepEmail = builtInAdminEmail;
    final collections = ['accounts', 'stalls', 'dishes', 'slots', 'orders', 'payouts', 'notifications'];
    for (final col in collections) {
      final snap = await _db.collection(col).get();
      for (final doc in snap.docs) {
        final data = doc.data();
        if (col == 'accounts' && (data['email'] == keepEmail)) continue;
        await doc.reference.delete();
      }
    }
    await _db.collection('counters').doc(builtInCampusId).delete();
  }
}
