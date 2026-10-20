import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import 'help_support_controller.dart';
import 'widgets/contact_option_tile.dart';

/// "Aide & support": a form that opens a support ticket (subject +
/// message), then the e-mail and phone to reach the team directly
/// (ContactOptionTile).
///
///   _Intro, _TicketForm, _ContactOptions
///
/// UI only: sending the ticket and the field rules live in
/// [HelpSupportController]; the text fields and the form key stay here.
class HelpSupportScreen extends ConsumerStatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  ConsumerState<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends ConsumerState<HelpSupportScreen> {
  /// This screen's own controller (see [helpSupportControllerProvider]).
  late final _provider = helpSupportControllerProvider(Object());
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSubmitting = ref.watch(_provider);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.helpSupport, style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _Intro(),
              const SizedBox(height: 30),
              _TicketForm(
                subjectController: _subjectController,
                messageController: _messageController,
                isSubmitting: isSubmitting,
                onSubmit: _submitTicket,
              ),
              const SizedBox(height: 30),
              const _ContactOptions(),
            ],
          ),
        ),
      ),
    );
  }

  // ── User actions ──────────────────────────────────────────────────────────

  Future<void> _submitTicket() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      await ref.read(_provider.notifier).submit(
            subject: _subjectController.text,
            message: _messageController.text,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.supportTicketSent),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.failedToSendTicket)),
        );
      }
    }
  }
}

// ── Sections ──────────────────────────────────────────────────────────────────

/// "Comment pouvons-nous vous aider ?" and its explanation.
class _Intro extends StatelessWidget {
  const _Intro();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          AppLocalizations.of(context)!.howCanWeHelp,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Text(
          AppLocalizations.of(context)!.fillFormDescription,
          style: const TextStyle(fontSize: 14, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// Subject, message and the send button.
class _TicketForm extends StatelessWidget {
  const _TicketForm({
    required this.subjectController,
    required this.messageController,
    required this.isSubmitting,
    required this.onSubmit,
  });

  final TextEditingController subjectController;
  final TextEditingController messageController;
  final bool isSubmitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: subjectController,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context)!.subject,
            prefixIcon: const Icon(Icons.title, color: AppColors.primary),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          validator: (value) => HelpSupportController.isMissing(value)
              ? AppLocalizations.of(context)!.pleaseEnterSubject
              : null,
        ),
        const SizedBox(height: 20),
        TextFormField(
          controller: messageController,
          maxLines: 6,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context)!.message,
            alignLabelWithHint: true,
            prefixIcon: const Padding(
              padding: EdgeInsets.only(bottom: 100),
              child: Icon(Icons.message_outlined, color: AppColors.primary),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          validator: (value) => HelpSupportController.isMissing(value)
              ? AppLocalizations.of(context)!.pleaseEnterMessage
              : null,
        ),
        const SizedBox(height: 40),
        ElevatedButton(
          onPressed: isSubmitting ? null : onSubmit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: isSubmitting
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(AppLocalizations.of(context)!.submitTicket, style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

/// The e-mail and phone to reach the team directly.
class _ContactOptions extends StatelessWidget {
  const _ContactOptions();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ContactOptionTile(
          icon: Icons.email_outlined,
          title: 'Email Us',
          subtitle: 'support@amana.tn',
        ),
        ContactOptionTile(
          icon: Icons.phone_outlined,
          title: AppLocalizations.of(context)!.callUs,
          subtitle: '+216 71 123 456',
        ),
      ],
    );
  }
}
