import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';
import '../providers/payment_provider.dart';
import 'widgets/payment_card_tile.dart';

/// The customer's saved cards, one PaymentCardTile each (swipe left to
/// delete). The + in the app bar adds one.
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
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: payments.length,
              itemBuilder: (context, index) {
                final card = payments[index];
                return PaymentCardTile(
                  card: card,
                  // Alternate dark / green cards down the list.
                  dark: index % 2 == 0,
                  onDelete: () {
                    ref.read(paymentProvider.notifier).deleteCard(card.id);
                  },
                );
              },
            ),
    );
  }

  void _showAddCardDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final numberController = TextEditingController();
    final expiryController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
              if (nameController.text.isNotEmpty && numberController.text.length >= 4) {
                ref.read(paymentProvider.notifier).addCard(
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
      ),
    );
  }
}
