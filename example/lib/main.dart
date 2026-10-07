import 'package:flutter/material.dart';
import 'package:didit_sdk/sdk_flutter.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Didit SDK Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1A1A1A)),
        useMaterial3: true,
      ),
      home: const VerificationScreen(),
    );
  }
}

class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  static const _demoWalletAddress =
      '0x71C7656EC7ab88b098defB751B7401B5f6d8976F';
  static const _verificationConfig = DiditConfig(
    languageCode: 'he',
    loggingEnabled: true,
  );

  final _tokenController = TextEditingController(text: 'Y6jHLOSXFTOA');
  final _workflowController = TextEditingController();
  final _transactionTokenController = TextEditingController();
  bool _loading = false;
  VerificationResult? _result;
  String? _transactionResult;

  @override
  void dispose() {
    _tokenController.dispose();
    _workflowController.dispose();
    _transactionTokenController.dispose();
    super.dispose();
  }

  Future<void> _startWithToken() async {
    final token = _tokenController.text.trim();
    if (token.isEmpty) {
      _showAlert('Error', 'Please enter a session token.');
      return;
    }

    setState(() {
      _loading = true;
      _result = null;
    });

    try {
      final result = await DiditSdk.startVerification(
        token,
        config: _verificationConfig,
      );
      setState(() => _result = result);
      _showResultAlert(result);
    } catch (e) {
      _showAlert('Error', 'Unexpected error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _startWithWorkflow() async {
    final workflowId = _workflowController.text.trim();
    if (workflowId.isEmpty) {
      _showAlert('Error', 'Please enter a workflow ID.');
      return;
    }

    setState(() {
      _loading = true;
      _result = null;
    });

    try {
      final result = await DiditSdk.startVerificationWithWorkflow(
        workflowId,
        config: _verificationConfig,
      );
      setState(() => _result = result);
      _showResultAlert(result);
    } catch (e) {
      _showAlert('Error', 'Unexpected error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _submitTransaction() async {
    final transactionToken = _transactionTokenController.text.trim();
    if (transactionToken.isEmpty) {
      _showAlert('Error', 'Please enter a transaction SDK token.');
      return;
    }

    setState(() {
      _loading = true;
      _transactionResult = null;
    });

    try {
      final result = await DiditSdk.submitTransaction(
        transactionToken,
        DiditTransactionPayload(
          txnId: 'flutter-demo-${DateTime.now().millisecondsSinceEpoch}',
          txnDate: DateTime.now().toUtc().toIso8601String(),
          type: 'crypto',
          info: const DiditTransactionInfo(
            direction: 'outbound',
            amount: 0.25,
            currency: 'ETH',
            currencyType: 'crypto',
            cryptoParams: {
              'address': _demoWalletAddress,
              'chain': 'ethereum',
            },
          ),
          subject: const DiditTransactionParticipant(
            type: 'individual',
            externalUserId: 'flutter-demo-user',
            fullName: 'Ada Lovelace',
          ),
          counterparty: const DiditTransactionParticipant(
            type: 'individual',
            fullName: 'Charles Babbage',
            paymentMethod: DiditTransactionPaymentMethod(
              type: 'crypto',
              accountId: _demoWalletAddress,
              issuingCountry: 'GB',
            ),
          ),
          travelRule: const DiditTravelRule(
            required: true,
            originatorData: {'full_name': 'Ada Lovelace'},
            beneficiaryData: {
              'full_name': 'Charles Babbage',
              'wallet_address': _demoWalletAddress,
            },
          ),
          includeCryptoScreening: true,
        ),
        options: DiditTransactionOptions(
          onTransactionUpdated: (updated) {
            setState(() {
              _transactionResult =
                  'Updated after action:\n${_describeTransaction(updated)}';
            });
          },
        ),
      );
      setState(() => _transactionResult = _describeTransaction(result));
    } on DiditTransactionException catch (e) {
      setState(() {
        _transactionResult = 'Error (${e.code}): ${e.message}'
            '${e.fieldErrors != null ? '\n${e.fieldErrors}' : ''}';
      });
    } catch (e) {
      setState(() => _transactionResult = 'Unexpected error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  String _describeTransaction(DiditTransactionResult result) {
    final action = result.actionRequired;
    return [
      'Transaction: ${result.transactionId}',
      'Status: ${result.status}',
      if (result.travelRuleStatus != null)
        'Travel rule: ${result.travelRuleStatus}',
      if (action == null)
        'Action required: none'
      else ...[
        'Action required: ${action.type}',
        if (action.url != null) '  url: ${action.url}',
        if (action.sessionId != null) '  session: ${action.sessionId}',
        if (action.widgetSessionId != null)
          '  widget session: ${action.widgetSessionId}',
      ],
    ].join('\n');
  }

  void _showResultAlert(VerificationResult result) {
    switch (result) {
      case VerificationCompleted(:final session):
        _showAlert(
          'Verification Complete',
          'Status: ${session.status.name}\nSession ID: ${session.sessionId}',
        );
      case VerificationCancelled():
        _showAlert('Cancelled', 'The user cancelled the verification.');
      case VerificationFailed(:final error):
        _showAlert('Failed', '${error.type.name}: ${error.message}');
    }
  }

  void _showAlert(String title, String message) {
    showDialog(
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              const Text(
                'Didit SDK',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                ),
                textAlign: TextAlign.center,
              ),
              const Text(
                'Flutter Example',
                style: TextStyle(fontSize: 16, color: Color(0xFF666666)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Token-based verification
              const Text(
                'Start with Session Token',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF333333),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _tokenController,
                decoration: InputDecoration(
                  hintText: 'Enter session token...',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                  ),
                ),
                autocorrect: false,
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loading ? null : _startWithToken,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A1A1A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Start Verification',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
              ),
              const SizedBox(height: 24),

              // Workflow-based verification
              const Text(
                'Start with Workflow ID',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF333333),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _workflowController,
                decoration: InputDecoration(
                  hintText: 'Enter workflow ID...',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                  ),
                ),
                autocorrect: false,
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loading ? null : _startWithWorkflow,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A4A4A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Start with Workflow',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
              ),
              const SizedBox(height: 24),

              // Transaction submission
              const Text(
                'Submit Sample Transaction',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF333333),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _transactionTokenController,
                decoration: InputDecoration(
                  hintText: 'Enter transaction SDK token...',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                  ),
                ),
                autocorrect: false,
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loading ? null : _submitTransaction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A4A4A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Submit Travel-Rule Transaction',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
              ),
              if (_transactionResult != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE0E0E0)),
                  ),
                  child: Text(
                    _transactionResult!,
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // Result display
              if (_result != null) ...[
                const Text(
                  'Last Result',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF333333),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE0E0E0)),
                  ),
                  child: _buildResultContent(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultContent() {
    final result = _result;
    if (result == null) return const SizedBox.shrink();

    switch (result) {
      case VerificationCompleted(:final session):
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _resultRow('Type', 'completed'),
            _resultRow('Status', session.status.name,
                color: session.status == VerificationStatus.approved
                    ? const Color(0xFF059669)
                    : session.status == VerificationStatus.declined
                        ? const Color(0xFFDC2626)
                        : null),
            _resultRow('Session', session.sessionId),
          ],
        );
      case VerificationCancelled():
        return _resultRow('Type', 'cancelled');
      case VerificationFailed(:final error):
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _resultRow('Type', 'failed'),
            _resultRow('Error', '${error.type.name} - ${error.message}'),
          ],
        );
    }
  }

  Widget _resultRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 14, color: Color(0xFF666666)),
          children: [
            TextSpan(text: '$label: '),
            TextSpan(
              text: value,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: color ?? const Color(0xFF1A1A1A),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
