import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthWidget extends StatefulWidget {
  // optional auth argument to allow mocking in tests
  final FirebaseAuth auth;


  AuthWidget({super.key, FirebaseAuth? auth})
    : auth = auth ?? FirebaseAuth.instance;

  @override
  State<AuthWidget> createState() => _AuthWidgetState();
}

class _AuthWidgetState extends State<AuthWidget> {
  bool _isLoginView = true;
  String? _errorMessage;

  // Controllers for login
  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();

  // Controllers for registration
  final _registerEmailController = TextEditingController();
  final _registerPasswordController = TextEditingController();
  final _registerConfirmPasswordController = TextEditingController();

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
    final email = _loginEmailController.text;
    final password = _loginPasswordController.text;

    setState(() => _errorMessage = null); // clear any previous error

    try {
      await widget.auth.signInWithEmailAndPassword(
        email: email,
        password: password,
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
  final email = _registerEmailController.text;
  final password = _registerPasswordController.text;
  final confirmPassword = _registerConfirmPasswordController.text;

  setState(() => _errorMessage = null); // clear any previous error

  if (password != confirmPassword) {
    setState(() => _errorMessage = 'Passwords do not match.');
    return;
  }

  try {
    await widget.auth.createUserWithEmailAndPassword(
      email: email,
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

  @override
  Widget build(BuildContext context) {


    return Card(
      margin: const EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Toggle button
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () => setState(() => _isLoginView = true),
                  child: Text(
                    'Login',
                    style: TextStyle(
                      fontWeight: _isLoginView
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _isLoginView = false),
                  child: Text(
                    'Register',
                    style: TextStyle(
                      fontWeight: _isLoginView
                          ? FontWeight.normal
                          : FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Show either login or registration form
            _isLoginView ? _buildLoginForm() : _buildRegisterForm(),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Column(
      children: [
        TextField(
          controller: _loginEmailController,
          decoration: const InputDecoration(
            labelText: 'Email',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _loginPasswordController,
          decoration: const InputDecoration(
            labelText: 'Password',
            border: OutlineInputBorder(),
          ),
          obscureText: true,
        ),
        const SizedBox(height: 16),

        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ElevatedButton(onPressed: _handleLogin, child: const Text('Login')),
      ],
    );
  }

  Widget _buildRegisterForm() {
    return Column(
      children: [
        TextField(
          controller: _registerEmailController,
          decoration: const InputDecoration(
            labelText: 'Email',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _registerPasswordController,
          decoration: const InputDecoration(
            labelText: 'Password',
            border: OutlineInputBorder(),
          ),
          obscureText: true,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _registerConfirmPasswordController,
          decoration: const InputDecoration(
            labelText: 'Confirm Password',
            border: OutlineInputBorder(),
          ),
          obscureText: true,
        ),
        const SizedBox(height: 16),
        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ElevatedButton(
          onPressed: _handleRegister,
          child: const Text('Register'),
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
    return Column(
      children: [
        ElevatedButton(onPressed: _handleLogout, child: const Text('Logout')),
      ],
    );
  }
}
