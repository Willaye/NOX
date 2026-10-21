import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

/// Admin-side companion to the employee enrollment flow. Replaces the old
/// "add device" screen that generated a magic link; this one calls
/// POST /enroll/invite which produces both an email + a landing URL the
/// admin can share directly.
class InviteEmployeeScreen extends ConsumerStatefulWidget {
  const InviteEmployeeScreen({super.key});

  @override
  ConsumerState<InviteEmployeeScreen> createState() => _InviteEmployeeScreenState();
}

class _InviteEmployeeScreenState extends ConsumerState<InviteEmployeeScreen> {
  final _email = TextEditingController();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _deviceName = TextEditingController();

  bool _busy = false;
  String? _error;
  String? _resultLink;
  String? _resultEmail;
  DateTime? _resultExpires;

  @override
  void dispose() {
    _email.dispose();
    _firstName.dispose();
    _lastName.dispose();
    _deviceName.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Enter a valid email');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final resp = await api.createEnrollmentInvite(
        email: email,
        firstName: _firstName.text.trim().isEmpty ? null : _firstName.text.trim(),
        lastName: _lastName.text.trim().isEmpty ? null : _lastName.text.trim(),
        deviceName:
            _deviceName.text.trim().isEmpty ? null : _deviceName.text.trim(),
      );
      final data = resp.data as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _resultLink = data['inviteUrl']?.toString();
        _resultEmail = data['email']?.toString();
        _resultExpires = DateTime.tryParse(data['expiresAt']?.toString() ?? '');
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _niceError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Invite employee', style: TextStyle(color: Colors.white)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "We'll email the employee a one-time link that installs the NOX agent on their phone. "
                "They don't need to type anything.",
                style: TextStyle(color: Color(0xFFCCCCCC), height: 1.5),
              ),
              const SizedBox(height: 24),
              _field(_email, 'Employee email', autofill: true),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _field(_firstName, 'First name (optional)')),
                const SizedBox(width: 12),
                Expanded(child: _field(_lastName, 'Last name (optional)')),
              ]),
              const SizedBox(height: 12),
              _field(_deviceName, 'Device label (optional)'),
              const SizedBox(height: 24),
              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A1A1A),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF553333)),
                  ),
                  child: Text(_error!,
                      style: const TextStyle(color: Color(0xFFFFBCBC))),
                ),
              FilledButton(
                onPressed: _busy ? null : _submit,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  backgroundColor: const Color(0xFF00E5FF),
                  foregroundColor: Colors.black,
                ),
                child: _busy
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                      )
                    : const Text('Send invite',
                        style: TextStyle(fontWeight: FontWeight.w700)),
              ),
              if (_resultLink != null) ...[
                const SizedBox(height: 24),
                _InviteResult(
                  email: _resultEmail ?? _email.text,
                  link: _resultLink!,
                  expires: _resultExpires,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label, {bool autofill = false}) {
    return TextField(
      controller: c,
      style: const TextStyle(color: Colors.white),
      keyboardType: autofill ? TextInputType.emailAddress : TextInputType.text,
      autofillHints: autofill ? const [AutofillHints.email] : null,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF888888)),
        filled: true,
        fillColor: const Color(0xFF111111),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF222222)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF00E5FF)),
        ),
      ),
    );
  }

  String _niceError(Object e) {
    final s = e.toString();
    if (s.contains('403')) return 'Only admins can invite employees.';
    if (s.contains('401')) return 'Please log in again.';
    if (s.contains('400')) return 'Please double-check the email.';
    if (s.contains('SocketException') || s.contains('Connection')) {
      return "Can't reach the server. Check your connection.";
    }
    return 'Something went wrong. Please try again.';
  }
}

class _InviteResult extends StatelessWidget {
  final String email;
  final String link;
  final DateTime? expires;
  const _InviteResult(
      {required this.email, required this.link, required this.expires});

  @override
  Widget build(BuildContext context) {
    final expiresStr = expires != null
        ? 'Expires ${expires!.toLocal().toIso8601String().split("T").first}'
        : null;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1F23),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF144955)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.mark_email_read_outlined,
                color: Color(0xFF00E5FF), size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Invite sent to $email',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ]),
          const SizedBox(height: 12),
          const Text(
            'If the employee can\'t find the email, share the link below with them directly '
            '(open it on the Android phone you want to enroll):',
            style: TextStyle(color: Color(0xFFCCCCCC), fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: SelectableText(link,
                  style: const TextStyle(
                      color: Color(0xFF00E5FF),
                      fontSize: 12,
                      fontFamily: 'monospace')),
            ),
            IconButton(
              icon: const Icon(Icons.copy, size: 18, color: Color(0xFF888888)),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: link));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invite link copied')),
                );
              },
            ),
          ]),
          if (expiresStr != null) ...[
            const SizedBox(height: 4),
            Text(expiresStr,
                style:
                    const TextStyle(color: Color(0xFF888888), fontSize: 12)),
          ],
        ],
      ),
    );
  }
}
