import 'package:flutter/material.dart';

import 'courier_colors.dart';

/// The big purple "Confirmer l'envoi • 7.000 TND" button at the bottom of
/// the "Colis" page (a spinner while sending).
class ConfirmSendButton extends StatelessWidget {
  final bool isBusy;
  final double? estimatedPrice;
  final VoidCallback onPressed;
  final double screenWidth;
  final double screenHeight;

  const ConfirmSendButton({
    super.key,
    required this.isBusy,
    required this.estimatedPrice,
    required this.onPressed,
    required this.screenWidth,
    required this.screenHeight,
  });

  @override
  Widget build(BuildContext context) {
    final w = screenWidth;
    final h = screenHeight;
    return SizedBox(
      width: double.infinity,
      height: h * 0.07,
      child: ElevatedButton(
        onPressed: isBusy ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: kCourierPurple,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(w * 0.04),
          ),
          elevation: 4,
        ),
        child: isBusy
            ? const CircularProgressIndicator(color: Colors.white)
            // scaleDown: label + price filled a 411-wide phone to the
            // last pixel and overflowed on narrower ones or with a
            // longer price. It now shrinks slightly instead.
            : FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.send_rounded),
                    SizedBox(width: w * 0.02),
                    Text(
                      'Confirmer l\'envoi',
                      style: TextStyle(
                        fontSize: w * 0.045,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (estimatedPrice != null) ...[
                      SizedBox(width: w * 0.02),
                      Text(
                        '• ${estimatedPrice!.toStringAsFixed(3)} TND',
                        style: TextStyle(
                          fontSize: w * 0.038,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}
