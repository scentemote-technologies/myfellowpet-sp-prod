import 'dart:js' as js;

class RazorpayPayment {
  // Function to open Razorpay payment modal
  void openPayment({
    required String key,
    required String amount,
    required String currency,
    required String name,
    required String description,
    required String image,
    required String email,
    required String contact,
    required Function onSuccess,
    required Function onFailure,
  }) {
    js.context.callMethod('openRazorpay', [
      {
        'key': key,
        'amount': amount,
        'currency': currency,
        'name': name,
        'description': description,
        'image': image,
        'email': email,
        'contact': contact,
        'handler': (response) {
          onSuccess(response);
        },
        'prefill': {
          'email': email,
          'contact': contact,
        },
        'notes': {
          'address': 'address', // Add any custom data here
        },
        'theme': {
          'color': '#F37254', // Customize the color as per your branding
        }
      }
    ]);
  }
}
