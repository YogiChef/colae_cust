import 'package:flutter_dotenv/flutter_dotenv.dart';

class StripePaymentSvice {
  Future<void> initPaymentSheet({
    required String amount,
    required String currency,
    required String merchantName,
  }) async {
    try {
      await dotenv.load();
    } catch (e) {
      throw Exception('Error initializing payment sheet: $e');
    }
  }

  Future<void> presentPaymentSheet() async {
    try {
      // await Stripe.instance.presentPaymentSheet();
    } catch (e) {
      throw Exception('Error presenting payment sheet: $e');
    }
  }
}
