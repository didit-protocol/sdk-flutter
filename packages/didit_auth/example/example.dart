import 'package:didit_auth/didit_auth.dart';
import 'package:flutter/material.dart';

// One client per application; reuse it.
const auth = DiditAuth(
  publishableKey: 'pk_test_...',
  redirectUri: 'https://app.example.com/didit/callback',
);

void main() => runApp(const MaterialApp(home: SignInPage()));

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  DiditSession? _session;
  String? _message;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() => _run(() async {
    _session = await auth.currentSession();
  });

  Future<void> _signIn() => _run(() async {
    _session = await auth.signIn();
  });

  Future<void> _signInWithPasskey() => _run(() async {
    _session = await auth.signInWithPasskey();
  });

  Future<void> _signOut() => _run(() async {
    await auth.signOut();
    _session = null;
  });

  Future<void> _payout() => _run(() async {
    final result = await auth.stepUp(
      const DiditPayoutStepUp(amount: '900.00', currency: 'EUR'),
    );
    // Your backend confirms with GET step-up/{id}/ before it pays out.
    _message = result.approved ? 'Step-up passed' : 'Step-up ${result.status}';
  });

  /// Runs a call, shows its failure by code, and redraws.
  Future<void> _run(Future<void> Function() call) async {
    String? message;
    try {
      await call();
    } on DiditAuthException catch (error) {
      // A person closing the page is not an error.
      if (error.code != DiditAuthErrorCodes.cancelled) {
        message = '${error.code}: ${error.message}';
      }
    }
    if (!mounted) return;
    setState(() => _message = message ?? _message);
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    return Scaffold(
      appBar: AppBar(title: const Text('Didit Authentication')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [
            Text(
              session == null ? 'Signed out' : 'Signed in as ${session.userId}',
            ),
            if (_message != null) Text(_message!),
            if (session == null) ...[
              FilledButton(onPressed: _signIn, child: const Text('Sign in')),
              OutlinedButton(
                onPressed: _signInWithPasskey,
                child: const Text('Sign in with a passkey'),
              ),
            ] else ...[
              FilledButton(
                onPressed: _payout,
                child: const Text('Pay out 900.00 EUR'),
              ),
              OutlinedButton(
                onPressed: _signOut,
                child: const Text('Sign out'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
