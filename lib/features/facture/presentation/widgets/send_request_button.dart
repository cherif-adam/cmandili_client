import 'package:flutter/material.dart';

import 'facture_colors.dart';

/// The big orange "Envoyer la demande" button (a spinner while sending).
class SendRequestButton extends StatelessWidget {
  final bool submitting;
  final VoidCallback onPressed;

  const SendRequestButton({
    super.key,
    required this.submitting,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: submitting ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: kFactureOrange,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: submitting
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text(
                'Envoyer la demande',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}
