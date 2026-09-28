import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cmandili_mobile/l10n/app_localizations.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../providers/cart_provider.dart';
import '../cart_screen.dart';

/// Bouton panier flottant, visible dès qu'il y a quelque chose dedans.
///
/// Le message d'ajout disparaît au bout de quelques secondes ; ce bouton
/// reste. C'est lui qui garantit qu'un client ayant pris trois offres
/// d'affilée retrouve le chemin de la commande. Il ouvre le panier normal,
/// donc la suite est celle de n'importe quelle commande — adresse, frais,
/// confirmation, suivi.
///
/// Renvoie `null` quand le panier est vide, pour être passé tel quel à
/// `Scaffold.floatingActionButton`.
class CartFab extends ConsumerWidget {
  const CartFab({super.key, required this.backgroundColor});

  final Color backgroundColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(cartItemCountProvider);
    if (count == 0) return const SizedBox.shrink();

    final l = AppLocalizations.of(context)!;
    final total = ref.watch(cartTotalProvider);

    return FloatingActionButton.extended(
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CartScreen()),
      ),
      backgroundColor: backgroundColor,
      foregroundColor: Colors.white,
      icon: Badge(
        label: Text('$count'),
        child: const Icon(Icons.shopping_cart_rounded),
      ),
      label: Text(
        '${l.viewCart}  ·  ${CurrencyFormatter.formatPrice(total)}',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }
}
