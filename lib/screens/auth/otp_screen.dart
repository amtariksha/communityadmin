import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:community_admin/config/theme.dart';
import 'package:community_admin/providers/auth_provider.dart';

class OtpScreen extends ConsumerStatefulWidget {
  final String phone;

  const OtpScreen({super.key, required this.phone});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  String _otp = '';

  Future<void> _verifyOtp() async {
    if (_otp.length != 6) return;

    final success = await ref
        .read(authStateProvider.notifier)
        .verifyOtp(widget.phone, _otp);

    if (success && mounted) {
      final state = ref.read(authStateProvider);
      if (state.user != null && state.user!.societies.length > 1) {
        context.go('/select-society');
      } else {
        context.go('/');
      }
    }
  }

  Future<void> _resendOtp() async {
    await ref.read(authStateProvider.notifier).sendOtp(widget.phone);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OTP resent successfully')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final maskedPhone =
        '${widget.phone.substring(0, 4)}****${widget.phone.substring(widget.phone.length - 2)}';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              Text(
                'Verify OTP',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter the 6-digit code sent to $maskedPhone',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.grey.shade600,
                    ),
              ),
              const SizedBox(height: 40),

              // QA #143 — OTP autofill. See note in
              // resident otp_screen.dart for the why.
              AutofillGroup(
                child: PinCodeTextField(
                  appContext: context,
                  length: 6,
                  onChanged: (value) => _otp = value,
                  onCompleted: (value) {
                    _otp = value;
                    _verifyOtp();
                  },
                  keyboardType: TextInputType.number,
                  animationType: AnimationType.fade,
                  pinTheme: PinTheme(
                    shape: PinCodeFieldShape.box,
                    borderRadius: BorderRadius.circular(12),
                    fieldHeight: 52,
                    fieldWidth: 48,
                    activeFillColor: Colors.grey.shade50,
                    inactiveFillColor: Colors.grey.shade50,
                    selectedFillColor: Colors.white,
                    activeColor: AppTheme.primaryColor,
                    inactiveColor: Colors.grey.shade300,
                    selectedColor: AppTheme.primaryColor,
                  ),
                  enableActiveFill: true,
                  autoFocus: true,
                ),
              ),
              const SizedBox(height: 8),

              if (authState.error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    authState.error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: authState.isLoading || _otp.length != 6
                      ? null
                      : _verifyOtp,
                  child: authState.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Verify'),
                ),
              ),

              const SizedBox(height: 24),
              Center(
                child: TextButton(
                  onPressed: authState.isLoading ? null : _resendOtp,
                  child: const Text('Resend OTP'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
