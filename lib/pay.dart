import 'dart:async';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'config.dart';

class PayResult {
  final bool ok;
  final String paymentId, message;
  const PayResult.success(this.paymentId)
      : ok = true,
        message = '';
  const PayResult.fail(this.message)
      : ok = false,
        paymentId = '';
}

/// Razorpay checkout kholta hai aur result wapas deta hai.
Future<PayResult> payWithRazorpay({
  required int amountRupees,
  required String description,
  String name = '',
  String email = '',
  String phone = '',
}) async {
  if (!AppConfig.razorpayReady) return const PayResult.fail('Razorpay key config.dart me add karo');
  final done = Completer<PayResult>();
  final rz = Razorpay();
  rz.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse r) {
    if (!done.isCompleted) done.complete(PayResult.success(r.paymentId ?? ''));
  });
  rz.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse r) {
    if (!done.isCompleted) done.complete(PayResult.fail(r.message ?? 'Payment cancelled'));
  });
  rz.on(Razorpay.EVENT_EXTERNAL_WALLET, (ExternalWalletResponse r) {});
  try {
    rz.open({
      'key': AppConfig.razorpayKeyId,
      'amount': amountRupees * 100,
      'currency': 'INR',
      'name': AppConfig.razorpayMerchantName,
      'description': description,
      'prefill': {'contact': phone, 'email': email, 'name': name},
      'theme': {'color': '#16181D'},
    });
  } catch (e) {
    rz.clear();
    return PayResult.fail('Payment start nahi ho paya');
  }
  final res = await done.future;
  rz.clear();
  return res;
}
