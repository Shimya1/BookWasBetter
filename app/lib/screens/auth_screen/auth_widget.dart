import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

class AuthWidget extends StatefulWidget {
  final FirebaseAuth auth;

  AuthWidget({super.key, FirebaseAuth? auth})
      : auth = auth ?? FirebaseAuth.instance;

  @override
  State<AuthWidget> createState() => _AuthWidgetState();
}

class _AuthWidgetState extends State<AuthWidget> {
  bool _isLoginView = true;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _errorMessage;

  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  final _registerEmailController = TextEditingController();
  final _registerPasswordController = TextEditingController();
  final _registerConfirmPasswordController = TextEditingController();

  static const _primary    = Color(0xFFB85C5C);
  static const _textDark   = Color(0xFF46281A);
  static const _textMid    = Color(0xFF6E3C3C);
  static const _borderClr  = Color(0xFFD4A574);
  static const _hintClr    = Color(0xFFB8926A);

  @override
  void dispose() {
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _registerEmailController.dispose();
    _registerPasswordController.dispose();
    _registerConfirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    setState(() => _errorMessage = null);
    try {
      await widget.auth.signInWithEmailAndPassword(
        email: _loginEmailController.text.trim(),
        password: _loginPasswordController.text,
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        switch (e.code) {
          case 'user-not-found':
          case 'wrong-password':
          case 'invalid-credential':
            _errorMessage = 'Incorrect email or password.';
          case 'invalid-email':
            _errorMessage = 'Please enter a valid email address.';
          case 'user-disabled':
            _errorMessage = 'This account has been disabled.';
          default:
            _errorMessage = 'An error occurred. Please try again.';
        }
      });
    }
  }

  Future<void> _handleRegister() async {
    final password = _registerPasswordController.text;
    final confirm  = _registerConfirmPasswordController.text;
    setState(() => _errorMessage = null);
    if (password != confirm) {
      setState(() => _errorMessage = 'Passwords do not match.');
      return;
    }
    try {
      await widget.auth.createUserWithEmailAndPassword(
        email: _registerEmailController.text.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        switch (e.code) {
          case 'weak-password':
            _errorMessage = 'Password must be at least 6 characters.';
          case 'email-already-in-use':
            _errorMessage = 'An account already exists for that email.';
          case 'invalid-email':
            _errorMessage = 'Please enter a valid email address.';
          default:
            _errorMessage = 'An error occurred. Please try again.';
        }
      });
    }
  }

  Future<void> _handleForgotPassword() async {
    final email = _loginEmailController.text.trim();
    if (email.isEmpty) {
      setState(() => _errorMessage = 'Enter your email above, then tap Forgot Password.');
      return;
    }
    try {
      await widget.auth.sendPasswordResetEmail(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password reset email sent.')),
        );
      }
    } on FirebaseAuthException {
      setState(() => _errorMessage = 'Could not send reset email. Check the address.');
    }
  }

  InputDecoration _fieldDecoration(String hint, IconData icon, {Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _hintClr),
      prefixIcon: Icon(icon, color: _textMid, size: 20),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _borderClr, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _primary),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _primary, width: 1.5),
      ),
    );
  }

  Widget _eyeIcon(bool obscure, VoidCallback onTap) {
    return IconButton(
      icon: Icon(
        obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        color: _textMid,
        size: 20,
      ),
      onPressed: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Logo
        Center(
          child: Image.asset('assets/images/title-image.png', width: 100),
        ),
        const SizedBox(height: 24),

        // Heading
        Text(
          _isLoginView ? 'Welcome Back' : 'Create Account',
          textAlign: TextAlign.center,
          style: GoogleFonts.playfairDisplay(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: _textDark,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _isLoginView
              ? 'Sign in to continue your reading journey.'
              : 'Join your book club community.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, color: _textMid),
        ),
        const SizedBox(height: 32),

        // Form fields
        _isLoginView ? _buildLoginForm() : _buildRegisterForm(),

        const SizedBox(height: 20),

        // Toggle between login / register
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _isLoginView ? "Don't have an account?  " : 'Already have an account?  ',
              style: const TextStyle(color: _textMid, fontSize: 14),
            ),
            GestureDetector(
              onTap: () => setState(() {
                _isLoginView = !_isLoginView;
                _errorMessage = null;
              }),
              child: Text(
                _isLoginView ? 'Sign Up' : 'Sign In',
                style: const TextStyle(
                  color: _primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLoginForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _loginEmailController,
          decoration: _fieldDecoration('Email', Icons.person_outline),
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _loginPasswordController,
          decoration: _fieldDecoration(
            'Password',
            Icons.lock_outline,
            suffix: _eyeIcon(_obscurePassword,
                () => setState(() => _obscurePassword = !_obscurePassword)),
          ),
          obscureText: _obscurePassword,
        ),
        const SizedBox(height: 20),
        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _primary, fontSize: 13),
            ),
          ),
        ElevatedButton(
          onPressed: _handleLogin,
          style: ElevatedButton.styleFrom(
            backgroundColor: _primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
          child: const Text('Sign In',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 16),
        Row(
          children: const [
            Expanded(child: Divider(color: _borderClr)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('or', style: TextStyle(color: _hintClr, fontSize: 13)),
            ),
            Expanded(child: Divider(color: _borderClr)),
          ],
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.center,
          child: TextButton(
            onPressed: _handleForgotPassword,
            child: const Text(
              'Forgot Password?',
              style: TextStyle(color: _primary, fontSize: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRegisterForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _registerEmailController,
          decoration: _fieldDecoration('Email', Icons.person_outline),
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _registerPasswordController,
          decoration: _fieldDecoration(
            'Password',
            Icons.lock_outline,
            suffix: _eyeIcon(_obscurePassword,
                () => setState(() => _obscurePassword = !_obscurePassword)),
          ),
          obscureText: _obscurePassword,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _registerConfirmPasswordController,
          decoration: _fieldDecoration(
            'Confirm Password',
            Icons.lock_outline,
            suffix: _eyeIcon(_obscureConfirm,
                () => setState(() => _obscureConfirm = !_obscureConfirm)),
          ),
          obscureText: _obscureConfirm,
        ),
        const SizedBox(height: 20),
        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _primary, fontSize: 13),
            ),
          ),
        ElevatedButton(
          onPressed: _handleRegister,
          style: ElevatedButton.styleFrom(
            backgroundColor: _primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
          child: const Text('Create Account',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

class LogoutWidget extends StatelessWidget {
  const LogoutWidget({super.key});

  Future<void> _handleLogout() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: _handleLogout,
      child: const Text('Logout'),
    );
  }
}