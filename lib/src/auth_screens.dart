import 'dart:async';
import 'package:flutter/material.dart';
import 'app_state.dart';
import 'db.dart';
import 'theme.dart';
import 'widgets.dart';

// ===========================================================================
// GATE — persistent root tree. Switches between splash / role picker / login
// internally (no Navigator pushes at the top level), so the post-login
// dashboard shell replaces it cleanly.
// ===========================================================================
enum _AuthStep { splash, choose, login }

class GateScreen extends StatefulWidget {
  const GateScreen({super.key});

  @override
  State<GateScreen> createState() => _GateScreenState();
}

class _GateScreenState extends State<GateScreen> {
  _AuthStep _step = _AuthStep.splash;
  AccountRole _role = AccountRole.customer;
  Timer? _splashTimer;

  @override
  void initState() {
    super.initState();
    _splashTimer = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => _step = _AuthStep.choose);
    });
  }

  @override
  void dispose() {
    _splashTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    switch (_step) {
      case _AuthStep.splash:
        return SplashScreen(onSkip: () => setState(() => _step = _AuthStep.choose));
      case _AuthStep.choose:
        return ChooseRoleScreen(
          initialRole: _role,
          onContinue: (role) => setState(() {
            _role = role;
            _step = _AuthStep.login;
          }),
        );
      case _AuthStep.login:
        return LoginRegisterScreen(
          role: _role,
          onBack: () => setState(() => _step = _AuthStep.choose),
        );
    }
  }
}

// ===========================================================================
// 1 · SPLASH
// ===========================================================================
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key, required this.onSkip});
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.yellow,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onSkip,
        child: SafeArea(
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Brand block centered in the available space.
              Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  GrabLogo(size: 118, splash: true),
                  SizedBox(height: 22),
                  Text('Grab&Go', style: TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: AppColors.navy900, letterSpacing: -1.2, height: 1)),
                  SizedBox(height: 8),
                  Text('Order ahead. Eat longer.', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.navy800)),
                ],
              ),
              // Footer pinned to the bottom.
              const Positioned(
                bottom: 26,
                left: 18,
                right: 18,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Break-time Allocation & Self-Service', textAlign: TextAlign.center, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.navy800)),
                    SizedBox(height: 2),
                    Text('Campus Cafeteria Ordering System', textAlign: TextAlign.center, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.navy800)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// 2 · CHOOSE ROLE
// ===========================================================================
class ChooseRoleScreen extends StatefulWidget {
  const ChooseRoleScreen({super.key, required this.initialRole, required this.onContinue});
  final AccountRole initialRole;
  final ValueChanged<AccountRole> onContinue;

  @override
  State<ChooseRoleScreen> createState() => _ChooseRoleScreenState();
}

class _ChooseRoleScreenState extends State<ChooseRoleScreen> {
  late AccountRole _selected = widget.initialRole;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.yellow,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  GrabLogo(size: 42),
                  const SizedBox(width: 10),
                  const Text('Grab&Go', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.navy900, letterSpacing: -0.6)),
                ],
              ),
              const SizedBox(height: 26),
              const Text('I am a…', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: AppColors.navy900, letterSpacing: -1)),
              const SizedBox(height: 2),
              const Text('Choose how you’ll use Grab&Go.', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.navy800)),
              const SizedBox(height: 20),
              _roleCard(
                role: AccountRole.customer,
                icon: Icons.school_rounded,
                tint: const Color(0xFFFBBF24),
                iconColor: AppColors.navy900,
                title: 'Customer',
                description: 'Order meals, pick a pickup window, and claim with your receipt.',
              ),
              const SizedBox(height: 12),
              _roleCard(
                role: AccountRole.stallAdmin,
                icon: Icons.storefront_rounded,
                tint: const Color(0xFFBBF7D0),
                iconColor: AppColors.greenDark,
                title: 'Stall admin',
                description: 'Prepare orders, verify receipts, manage dishes and stock.',
              ),
              const SizedBox(height: 12),
              _roleCard(
                role: AccountRole.mainAdmin,
                icon: Icons.shield_rounded,
                tint: const Color(0xFFBFDBFE),
                iconColor: const Color(0xFF1D4ED8),
                title: 'Main admin',
                description: 'Manage stalls, accounts, and sales across the canteen.',
              ),
              const Spacer(),
              NavyButton(
                label: 'Continue as ${roleLabelOf(_selected)}',
                onPressed: () => widget.onContinue(_selected),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _roleCard({
    required AccountRole role,
    required IconData icon,
    required Color tint,
    required Color iconColor,
    required String title,
    required String description,
  }) {
    final selected = _selected == role;
    return GestureDetector(
      onTap: () => setState(() => _selected = role),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppColors.navy900 : Colors.transparent, width: 2.4),
          boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0, 3))],
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(16)),
              child: Icon(icon, color: iconColor, size: 26),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w900, color: AppColors.navy900, letterSpacing: -0.3)),
                  const SizedBox(height: 2),
                  Text(description, style: const TextStyle(fontSize: 11, height: 1.4, color: AppColors.muted)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(shape: BoxShape.circle, color: selected ? AppColors.navy900 : Colors.transparent, border: Border.all(color: selected ? AppColors.navy900 : const Color(0xFFD4D4DE), width: 1.8)),
              alignment: Alignment.center,
              child: selected ? const Icon(Icons.check_rounded, size: 16, color: Colors.white) : null,
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// 3 & 4 · LOG IN / CREATE ACCOUNT
// ===========================================================================
class LoginRegisterScreen extends StatefulWidget {
  const LoginRegisterScreen({super.key, required this.role, required this.onBack});
  final AccountRole role;
  final VoidCallback onBack;

  @override
  State<LoginRegisterScreen> createState() => _LoginRegisterScreenState();
}

class _LoginRegisterScreenState extends State<LoginRegisterScreen> {
  int _tab = 0; // 0 = Log in, 1 = Create account

  // login fields
  final _loginEmailCtrl = TextEditingController();
  final _loginPassCtrl = TextEditingController();
  final _loginIdCtrl = TextEditingController();
  String? _loginError;
  bool _loginBusy = false;
  bool _obscureLogin = true;

  // register fields
  final _regNameCtrl = TextEditingController();
  final _regIdCtrl = TextEditingController();
  final _regEmailCtrl = TextEditingController();
  final _regPassCtrl = TextEditingController();
  final _regConfirmCtrl = TextEditingController();
  String _regType = 'Student';
  String? _regNameError, _regIdError, _regEmailError, _regPassError, _regConfirmError;
  bool _obscureReg = true;
  bool _obscureConfirm = true;
  bool _regBusy = false;

  bool get _isCustomer => widget.role == AccountRole.customer;

  @override
  void dispose() {
    _loginEmailCtrl.dispose();
    _loginPassCtrl.dispose();
    _loginIdCtrl.dispose();
    _regNameCtrl.dispose();
    _regIdCtrl.dispose();
    _regEmailCtrl.dispose();
    _regPassCtrl.dispose();
    _regConfirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _loginEmailCtrl.text.trim();
    final pass = _loginPassCtrl.text;
    setState(() {
      _loginError = null;
    });

    if (email.isEmpty) {
      setState(() => _loginError = 'Enter your email.');
      return;
    }
    if (pass.length < 8) {
      setState(() => _loginError = 'Password must be at least 8 characters.');
      return;
    }
    // School ID is optional — email + password is the credential.
    // If one is typed, just check the format so the field isn't broken.
    final id = _loginIdCtrl.text.trim();
    if (id.isNotEmpty && !RegExp(AppState.instance.requiredCampus.idPattern).hasMatch(id)) {
      setState(() => _loginError = 'School ID must look like ${AppState.instance.requiredCampus.idHint} (or leave it blank).');
      return;
    }

    setState(() => _loginBusy = true);
    if (!mounted) return;

    final error = await AppState.instance.signIn(email, pass);
    if (!mounted) return;
    if (error == null) {
      // AppState now carries a signed-in user — the root _Gate rebuilds into
      // the correct role shell automatically (this is a parallel route in
      // the same page tree, not a Navigator).
      setState(() {
        _loginBusy = false;
        _loginError = null;
      });
      return;
    }
    setState(() {
      _loginBusy = false;
      _loginError = error;
    });
  }

  Future<void> _register() async {
    final emailRx = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');
    final idRx = RegExp(AppState.instance.requiredCampus.idPattern);
    final name = _regNameCtrl.text.trim();
    final id = _regIdCtrl.text.trim();
    final email = _regEmailCtrl.text.trim().toLowerCase();
    final pass = _regPassCtrl.text;
    final confirm = _regConfirmCtrl.text;

    setState(() {
      _regNameError = name.isEmpty ? 'Full name is required.' : null;
      if (_regType != 'Visitor') {
        _regIdError = id.isEmpty
            ? 'School ID is required.'
            : (!idRx.hasMatch(id) ? 'School ID must look like 23-12345.' : null);
      } else {
        _regIdError = id.isNotEmpty && !idRx.hasMatch(id) ? 'School ID must look like 23-12345.' : null;
      }
      _regEmailError = emailRx.hasMatch(email) ? null : 'Enter a valid email, like name@g.batstate-u.edu.ph.';
      _regPassError = pass.length >= 8 ? null : 'Password must be at least 8 characters.';
      _regConfirmError = confirm == pass ? null : 'Passwords don’t match.';
    });

    if ([_regNameError, _regIdError, _regEmailError, _regPassError, _regConfirmError].any((e) => e != null)) return;

    setState(() => _regBusy = true);
    final error = await AppState.instance.registerCustomerAsync(name: name, schoolId: id, type: _regType, email: email, password: pass);
    if (!mounted) return;
    if (error == null) {
      setState(() {
        _regBusy = false;
        _regEmailError = null;
      });
      return;
    }
    setState(() {
      _regBusy = false;
      _regEmailError = error;
    });
    // Session is set; the auth gate takes over.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 14, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  BackLink(label: 'Back', onTap: widget.onBack),                  GestureDetector(
                    onTap: widget.onBack,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: AppColors.yellowSoft, borderRadius: BorderRadius.circular(20)),
                      child: Row(
                        children: [
                          Icon(_isCustomer ? Icons.person_rounded : (widget.role == AccountRole.stallAdmin ? Icons.storefront_rounded : Icons.shield_rounded), size: 14, color: AppColors.yellowOnSoft),
                          const SizedBox(width: 6),
                          Text('${roleLabelOf(widget.role)} · Change role', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.yellowOnSoft)),
                          const SizedBox(width: 2),
                          const Icon(Icons.chevron_right_rounded, size: 15, color: AppColors.yellowOnSoft),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 10, 22, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        GrabLogo(size: 54),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text('Grab&Go', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900, color: AppColors.navy900, letterSpacing: -0.8, height: 1)),
                            SizedBox(height: 4),
                            Text('Order ahead. Eat longer.', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.muted)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (!_isCustomer) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: AppColors.blueSoft, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.blue.withValues(alpha: 0.3))),
                        child: Text(
                          widget.role == AccountRole.stallAdmin
                              ? 'Stall admin accounts are created by the main admin. Sign in with the credentials given to you.'
                              : 'Main admin accounts are built into this device by the canteen office. Sign in to manage the canteen.',
                          style: const TextStyle(fontSize: 11.5, height: 1.45, color: Color(0xFF1E40AF), fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    if (_isCustomer) Segmented(items: const ['Log in', 'Register'], selected: _tab, onChanged: (i) => setState(() => _tab = i)),
                    if (_isCustomer) const SizedBox(height: 14),
                    if (_isCustomer && _tab == 1) _registerForm() else _loginForm(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- login tab ----------------
  Widget _loginForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_loginError != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.redSoft, borderRadius: BorderRadius.circular(12)),
            child: Text(_loginError!, style: const TextStyle(color: AppColors.redDark, fontSize: 12, fontWeight: FontWeight.w600, height: 1.4)),
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: _loginEmailCtrl,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration: InputDecoration(labelText: 'Email', hintText: _isCustomer ? 'janna@batstate-u.edu.ph' : 'name@batstate-u.edu.ph'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _loginPassCtrl,
          obscureText: _obscureLogin,
          decoration: InputDecoration(
            labelText: 'Password',
            hintText: 'Minimum 8 characters',
            errorText: _loginError != null && _loginPassCtrl.text.length < 8 ? 'Password must be at least 8 characters.' : null,
            suffixIcon: IconButton(icon: Icon(_obscureLogin ? Icons.visibility_off_outlined : Icons.visibility_outlined), onPressed: () => setState(() => _obscureLogin = !_obscureLogin)),
          ),
        ),
        if (_isCustomer) ...[
          const SizedBox(height: 10),
          TextField(
            controller: _loginIdCtrl,
            decoration: const InputDecoration(labelText: 'School ID (optional)', hintText: '23-12345'),
          ),
        ],
        const SizedBox(height: 16),
        PrimaryButton(
          label: 'Log in',
          loading: _loginBusy,
          onPressed: _loginBusy ? null : _login,
        ),
        const SizedBox(height: 14),
        const Center(child: Text('Stall and main admins log in here too, without Register', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.muted))),
        if (_isCustomer) ...[
          const SizedBox(height: 4),
          Center(
            child: GestureDetector(
              onTap: () => setState(() => _tab = 1),
              child: const Text('Don’t have an account? Register', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.navy900)),
            ),
          ),
        ],
      ],
    );
  }

  // ---------------- register tab ----------------
  Widget _registerForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Create account', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.navy900, letterSpacing: -0.5)),
        const SizedBox(height: 2),
        const Text('Stall and main admin accounts are created by the canteen office.', style: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.4)),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ['Student', 'Employee', 'Visitor'].map((t) => SelectChip(label: t, selected: _regType == t, onTap: () => setState(() => _regType = t))).toList(),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _regNameCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(labelText: 'Full name', hintText: 'Janna Reyes', errorText: _regNameError),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _regIdCtrl,
          decoration: InputDecoration(labelText: _regType == 'Visitor' ? 'School ID (optional for visitors)' : 'School ID', hintText: '23-12345', errorText: _regIdError),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _regEmailCtrl,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration: InputDecoration(labelText: 'Email', hintText: 'janna@batstate-u.edu.ph', errorText: _regEmailError),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _regPassCtrl,
          obscureText: _obscureReg,
          decoration: InputDecoration(
            labelText: 'Password',
            hintText: 'Minimum 8 characters',
            errorText: _regPassError,
            suffixIcon: IconButton(icon: Icon(_obscureReg ? Icons.visibility_off_outlined : Icons.visibility_outlined), onPressed: () => setState(() => _obscureReg = !_obscureReg)),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _regConfirmCtrl,
          obscureText: _obscureConfirm,
          decoration: InputDecoration(
            labelText: 'Confirm password',
            hintText: 'Re-type your password',
            errorText: _regConfirmError,
            suffixIcon: IconButton(icon: Icon(_obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined), onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm)),
          ),
        ),
        const SizedBox(height: 16),
        PrimaryButton(label: 'Register', loading: _regBusy, onPressed: _regBusy ? null : _register),
        const SizedBox(height: 12),
        Center(
          child: GestureDetector(
            onTap: () => setState(() => _tab = 0),
            child: const Text('Already have an account? Log in', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.navy900)),
          ),
        ),
      ],
    );
  }
}
