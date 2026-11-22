// The Material library moved to package:material_ui in newer Flutter releases;
// the import still works, so the deprecation is acknowledged here.
// ignore_for_file: deprecated_member_use

// The Bank Link page: paste a link's client token, open the flow, and watch the
// event stream and the result next to it. Used by the manual device matrix on
// both platforms against the sandbox test bank.
import 'dart:async';
import 'dart:convert';

import 'package:didit_sdk/sdk_flutter.dart';
import 'package:flutter/material.dart';

class BankLinkPage extends StatefulWidget {
  const BankLinkPage({super.key});

  @override
  State<BankLinkPage> createState() => _BankLinkPageState();
}

class _BankLinkPageState extends State<BankLinkPage> {
  // The link's `client_token` (`blt_...`), minted by the customer's backend.
  // The API key never reaches the app.
  final _tokenController = TextEditingController();
  final _events = <BankLinkEvent>[];
  StreamSubscription<BankLinkEvent>? _subscription;
  BankLinkResult? _result;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _subscription = DiditSdk.bankLinkEvents.listen((event) {
      setState(() => _events.insert(0, event));
    });
    // A link whose bank trip outlived the app is picked up here, with the step
    // the person was on.
    _resume();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _resume() async {
    final result = await DiditSdk.resumeBankLink();
    if (result != null && mounted) {
      setState(() => _result = result);
    }
  }

  Future<void> _present() async {
    final token = _tokenController.text.trim();
    if (token.isEmpty) {
      _showAlert('Bank Link', 'Paste the link\'s client token first.');
      return;
    }

    setState(() {
      _running = true;
      _result = null;
      _events.clear();
    });

    final result = await DiditSdk.presentBankLink(
      token,
      options: const BankLinkOptions(config: DiditConfig(loggingEnabled: true)),
    );

    if (!mounted) return;
    setState(() {
      _running = false;
      _result = result;
    });
  }

  void _showAlert(String title, String message) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _describe(BankLinkResult result) => switch (result) {
    BankLinkSuccess(:final linkId, :final connectionId, :final checkId) => [
      'Success',
      'link: $linkId',
      if (connectionId != null) 'connection: $connectionId',
      if (checkId != null) 'check: $checkId',
      if (result.resumed) 'replayed after a relaunch',
    ].join('\n'),
    BankLinkExit(:final reason, :final step) => [
      'Exit: ${reason.wireName}',
      if (step != null) 'step: $step',
      if (result.resumed) 'replayed after a relaunch',
    ].join('\n'),
  };

  @override
  Widget build(BuildContext context) {
    final result = _result;

    return Scaffold(
      appBar: AppBar(title: const Text('Bank Link')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Paste the link\'s client token (blt_...)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _tokenController,
                autocorrect: false,
                decoration: InputDecoration(
                  hintText: 'blt_...',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _running ? null : _present,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A1A1A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _running
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Present Bank Link'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _resume,
                child: const Text('Resume a pending link'),
              ),
              if (result != null) ...[
                const SizedBox(height: 24),
                const Text(
                  'Result',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  _describe(result),
                  style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                ),
              ],
              const SizedBox(height: 24),
              const Text(
                'Events',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              if (_events.isEmpty)
                const Text(
                  'No events yet.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF666666)),
                ),
              for (final event in _events)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '${event.name} ${jsonEncode(event.data)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
