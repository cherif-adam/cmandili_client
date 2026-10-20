import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';
import '../../providers/payment_provider.dart';
import 'widgets/payment_card_tile.dart';

/// The customer's saved cards, one PaymentCardTile each (swipe left to
/// delete). The + in the app bar adds one.
///
/// UI only: the cards, adding and deleting live in [paymentProvider]
/// (PaymentNotifier, PaymentMethodRepository behind it).
class PaymentMethodsScreen extends ConsumerWidget {
  const PaymentMethodsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payments = ref.watch(paymentProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.paymentMethods, style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_card),
            onPressed: () => _showAddCardDialog(context, ref),
          ),
        ],
      ),
      body: payments.isEmpty
          ? Center(child: Text(AppLocalizations.of(context)!.noPaymentMethods))
          : _CardsList(
              cards: payments,
              onDelete: (card) =>
                  ref.read(paymentProvider.notifier).deleteCard(card.id),
            ),
    );
  }

  void _showAddCardDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => _AddCardDialog(
        onSave: (name, number, expiry) =>
            ref.read(paymentProvider.notifier).addCard(name, number, expiry),
      ),
    );
  }
}

// ── Sections ──────────────────────────────────────────────────────────────────

/// One PaymentCardTile per card, dark and green alternating down the list.
class _CardsList extends StatelessWidget {
  const _CardsList({required this.cards, required this.onDelete});

  final List<PaymentMethod> cards;
  final ValueChanged<PaymentMethod> onDelete;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: cards.length,
      itemBuilder: (context, index) {
        final card = cards[index];
        return PaymentCardTile(
          card: card,
          // Alternate dark / green cards down the list.
          dark: index % 2 == 0,
          onDelete: () => onDelete(card),
        );
      },
    );
  }
}

/// Name, card number and expiry. "Enregistrer" only closes the dialog once
/// [PaymentNotifier.canAddCard] accepts the input.
class _AddCardDialog extends StatefulWidget {
  const _AddCardDialog({required this.onSave});

  final void Function(String name, String number, String expiry) onSave;

  @override
  State<_AddCardDialog> createState() => _AddCardDialogState();
}

class _AddCardDialogState extends State<_AddCardDialog> {
  final nameController = TextEditingController();
  final numberController = TextEditingController();
  final expiryController = TextEditingController();

  @override
  void dispose() {
    nameController.dispose();
    numberController.dispose();
    expiryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(AppLocalizations.of(context)!.addNewCard),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameController,
            decoration: InputDecoration(labelText: AppLocalizations.of(context)!.cardholderName),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: numberController,
            decoration: InputDecoration(labelText: AppLocalizations.of(context)!.cardNumber),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: expiryController,
            decoration: InputDecoration(labelText: AppLocalizations.of(context)!.expiryDate),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppLocalizations.of(context)!.cancel),
        ),
        ElevatedButton(
          onPressed: () {
            if (PaymentNotifier.canAddCard(nameController.text, numberController.text)) {
              widget.onSave(
                nameController.text,
                numberController.text,
                expiryController.text,
              );
              Navigator.pop(context);
            }
          },
          child: Text(AppLocalizations.of(context)!.save),
        ),
      ],
    );
  }
}
