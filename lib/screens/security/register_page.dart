import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:anzioworkshopapp/services/backend_service.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> with SingleTickerProviderStateMixin {
  final _nameController            = TextEditingController();
  final _emailController           = TextEditingController();
  final _passwordController        = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _loading           = false;
  bool _obscurePassword   = true;
  bool _obscureConfirm    = true;
  late AnimationController _animController;
  late Animation<double>   _fadeAnim;
  late Animation<Offset>   _slideAnim;

  // ── Brand colours (same palette as LoginPage) ──────────────────────────────
  static const _bgColor       = Color(0xFF0E0E1A);
  static const _cardColor     = Color(0xFF1A1A2E);
  static const _surfaceColor  = Color(0xFF16213E);
  static const _accentTeal    = Color(0xFF00D4AA);
  static const _textPrimary   = Color(0xFFE8EAF6);
  static const _textSecondary = Color(0xFF8B92B8);
  static const _borderColor   = Color(0xFF2A2D4A);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    setState(() => _loading = true);

    final name            = _nameController.text.trim();
    final email           = _emailController.text.trim();
    final password        = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      _showSnack('Harap isi semua kolom', isError: true);
      if (mounted) setState(() => _loading = false);
      return;
    }

    if (password != confirmPassword) {
      _showSnack('Password tidak cocok', isError: true);
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final created = await BackendService.createTechnician(name, email, password);
      if (!mounted) return;

      if (created) {
        _showSnack('Registrasi berhasil!');
        await Future.delayed(const Duration(seconds: 1));
        if (!mounted) return;
        Navigator.pop(context);
      } else {
        _showSnack('Registrasi gagal. Email mungkin sudah digunakan.', isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: isError ? const Color(0xFFE53935) : _accentTeal,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: _bgColor,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Back button ────────────────────────────────────────
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _borderColor),
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: _textSecondary,
                          size: 18,
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // ── Header ─────────────────────────────────────────────
                    Center(
                      child: Column(
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [_accentTeal, Color(0xFF0094FF)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: _accentTeal.withOpacity(0.35),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.person_add_rounded,
                              color: Colors.white,
                              size: 36,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Buat Akun Baru',
                            style: TextStyle(
                              color: _textPrimary,
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Daftarkan diri Anda sebagai teknisi',
                            style: TextStyle(
                              color: _textSecondary,
                              fontSize: 14,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 36),

                    // ── Form card ──────────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: _cardColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _borderColor, width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Name
                          _fieldLabel('Nama Lengkap'),
                          const SizedBox(height: 8),
                          _buildTextField(
                            controller: _nameController,
                            hint: 'Masukkan nama lengkap',
                            icon: Icons.person_outline_rounded,
                            formatters: [LengthLimitingTextInputFormatter(100)],
                          ),

                          const SizedBox(height: 20),

                          // Email
                          _fieldLabel('Email'),
                          const SizedBox(height: 8),
                          _buildTextField(
                            controller: _emailController,
                            hint: 'contoh@email.com',
                            icon: Icons.email_outlined,
                            inputType: TextInputType.emailAddress,
                            formatters: [LengthLimitingTextInputFormatter(254)],
                          ),

                          const SizedBox(height: 20),

                          // Password
                          _fieldLabel('Password'),
                          const SizedBox(height: 8),
                          _buildTextField(
                            controller: _passwordController,
                            hint: '••••••••',
                            icon: Icons.lock_outline_rounded,
                            obscure: _obscurePassword,
                            formatters: [LengthLimitingTextInputFormatter(100)],
                            suffixIcon: _visibilityToggle(
                              obscure: _obscurePassword,
                              onTap: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Confirm Password
                          _fieldLabel('Konfirmasi Password'),
                          const SizedBox(height: 8),
                          _buildTextField(
                            controller: _confirmPasswordController,
                            hint: '••••••••',
                            icon: Icons.lock_outline_rounded,
                            obscure: _obscureConfirm,
                            formatters: [LengthLimitingTextInputFormatter(100)],
                            suffixIcon: _visibilityToggle(
                              obscure: _obscureConfirm,
                              onTap: () => setState(() => _obscureConfirm = !_obscureConfirm),
                            ),
                          ),

                          const SizedBox(height: 28),

                          // ── Register button ──────────────────────────────
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: _loading
                                    ? null
                                    : const LinearGradient(
                                        colors: [_accentTeal, Color(0xFF0094FF)],
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                      ),
                                color: _loading ? _surfaceColor : null,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: _loading
                                    ? []
                                    : [
                                        BoxShadow(
                                          color: _accentTeal.withOpacity(0.30),
                                          blurRadius: 16,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                              ),
                              child: ElevatedButton(
                                onPressed: _loading ? null : _register,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: _loading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: _accentTeal,
                                        ),
                                      )
                                    : const Text(
                                        'Buat Akun',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Back to login ──────────────────────────────────────
                    Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Sudah punya akun? ',
                            style: TextStyle(color: _textSecondary, fontSize: 14),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: const Text(
                              'Masuk di sini',
                              style: TextStyle(
                                color: _accentTeal,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // ── Decorative bottom accent ───────────────────────────
                    Center(
                      child: Container(
                        width: 48,
                        height: 4,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [_accentTeal, Color(0xFF0094FF)],
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _fieldLabel(String text) => Text(
        text,
        style: const TextStyle(
          color: _textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.3,
        ),
      );

  Widget _visibilityToggle({required bool obscure, required VoidCallback onTap}) =>
      IconButton(
        icon: Icon(
          obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          color: _textSecondary,
          size: 20,
        ),
        onPressed: onTap,
      );

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType inputType = TextInputType.text,
    bool obscure = false,
    List<TextInputFormatter>? formatters,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: inputType,
      inputFormatters: formatters,
      style: const TextStyle(color: _textPrimary, fontSize: 15),
      cursorColor: _accentTeal,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _textSecondary, fontSize: 14),
        prefixIcon: Icon(icon, color: _textSecondary, size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: _surfaceColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _borderColor, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _accentTeal, width: 1.5),
        ),
      ),
    );
  }
}