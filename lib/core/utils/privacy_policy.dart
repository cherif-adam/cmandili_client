import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

/// Amana's privacy policy, the same page as the Google Play listing.
const kPrivacyPolicyUrl = 'https://sites.google.com/view/amana-kairouan-privacy';

/// Opens the privacy policy in the browser, and says so when it can't.
Future<void> openPrivacyPolicy(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  final failed = AppLocalizations.of(context)!.privacyPolicyOpenFailed;
  var opened = false;
  try {
    opened = await launchUrl(Uri.parse(kPrivacyPolicyUrl),
        mode: LaunchMode.externalApplication);
  } catch (_) {}
  if (!opened) messenger.showSnackBar(SnackBar(content: Text(failed)));
}
