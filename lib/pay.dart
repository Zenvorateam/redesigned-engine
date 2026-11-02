import 'dart:async';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'config.dart';

class PayResult {
  final bool ok;
  final String paymentId, signature, message;
  const PayResult.success(this.paymentId, this.signature)
      : ok = true,
        message = '';
  const PayResult.fail(this.message)
      : ok = false,
        paymentId = '',
        signature = '';
}

/// Razorpay checkout kholta hai aur result wapas deta hai.
Future<PayResult> payWithRazorpay({
  required int amountRupees,
  required String description,
  required String razorpayOrderId,
  required String razorpayKeyId,
  String name = '',
  String email = '',
  String phone = '',
}) async {
  if (razorpayKeyId.isEmpty) return const PayResult.fail('Online payment is not configured');
  final done = Completer<PayResult>();
  final rz = Razorpay();
  rz.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse r) {
    if (!done.isCompleted) done.complete(PayResult.success(r.paymentId ?? '', r.signature ?? ''));
  });
  rz.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse r) {
    if (!done.isCompleted) done.complete(PayResult.fail(r.message ?? 'Payment cancelled'));
  });
  rz.on(Razorpay.EVENT_EXTERNAL_WALLET, (ExternalWalletResponse r) {});
  try {
    rz.open({
      'key': razorpayKeyId,
      'amount': amountRupees * 100,
      'order_id': razorpayOrderId,
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
