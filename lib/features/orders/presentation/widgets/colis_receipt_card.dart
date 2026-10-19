// Bon de prise en charge, vu par l'expéditeur.
//
// Trois moments dans la vie d'un colis, trois affichages :
//   avant la remise  → le code à 4 chiffres, à transmettre au destinataire ;
//   après la remise  → les preuves (photos, livreur, plaque) ;
//   dans les 24 h    → le bouton de signalement.
//
// La carte ne rend rien du tout quand il n'y a pas de reçu : commande qui
// n'est pas un colis, ou migration pas encore appliquée. Un build neuf doit
// rester utilisable sur une base pas à jour.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../courier/data/colis_repository.dart';

class ColisReceiptCard extends StatefulWidget {
  const ColisReceiptCard({
    super.key,
    required this.orderId,
    required this.deliveredAt,
    this.repository,
  });

  final String orderId;
  final DateTime? deliveredAt;

  /// Injectable pour les tests ; l'app utilise le dépôt par défaut.
  final ColisRepository? repository;

  @override
  State<ColisReceiptCard> createState() => _ColisReceiptCardState();
}

class _ColisReceiptCardState extends State<ColisReceiptCard> {
  late final ColisRepository _repo = widget.repository ?? ColisRepository();

  Map<String, dynamic>? _receipt;
  String? _code;
  String? _pickupUrl;
  String? _deliveryUrl;
  bool _loading = true;
  bool _disputeSent = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final receipt = await _repo.loadReceipt(widget.orderId);
    if (receipt == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    final code = receipt['delivery_mode'] == 'code'
        ? await _repo.loadDeliveryCode(widget.orderId)
        : null;

    final pickupPath = receipt['pickup_photo_path'] as String?;
    final deliveryPath = receipt['delivery_photo_path'] as String?;

    final pickupUrl =
        pickupPath == null ? null : await _repo.signedProofUrl(pickupPath);
    final deliveryUrl =
        deliveryPath == null ? null : await _repo.signedProofUrl(deliveryPath);

    if (!mounted) return;
    setState(() {
      _receipt = receipt;
      _code = code;
      _pickupUrl = pickupUrl;
      _deliveryUrl = deliveryUrl;
      _loading = false;
    });
  }

  void _shareCode() {
    final code = _code;
    if (code == null) return;
    // Le message part au DESTINATAIRE, pas à l'expéditeur : il s'adresse donc
    // à lui, le salue, et dit quoi faire du code. L'ancienne formulation
    // (« Votre colis arrive bientôt ») parlait à la mauvaise personne.
    final l10n = AppLocalizations.of(context)!;
    Share.share(
      l10n.colisShareMessage(code),
      subject: l10n.colisShareSubject,
    );
  }

  Future<void> _openDispute(String kind, String label) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(label),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppLocalizations.of(ctx)!.colisDisputeExplain,
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: AppLocalizations.of(ctx)!.colisDisputeMessageHint,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(AppLocalizations.of(ctx)!.cancel)),
          ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(AppLocalizations.of(ctx)!.rateDriverSend)),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _repo.openDispute(
        orderId: widget.orderId,
        kind: kind,
        message: controller.text.trim().isEmpty ? null : controller.text.trim(),
      );
      if (mounted) setState(() => _disputeSent = true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e is PostgrestException
            ? e.message
            : AppLocalizations.of(context)!.colisDisputeSendFailed),
        backgroundColor: Colors.red,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _receipt == null) return const SizedBox.shrink();
    final r = _receipt!;
    final l10n = AppLocalizations.of(context)!;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x14000000), blurRadius: 14, offset: Offset(0, 5)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long_rounded, size: 20),
              const SizedBox(width: 8),
              Text(l10n.colisReceiptTitle,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 14),

          // ── Le code, tant que le colis n'est pas remis ───────────────────
          if (_code != null && r['delivery_at'] == null) _DeliveryCodeBlock(code: _code!, onShare: _shareCode),

          _ReceiptLine(l10n.colisReceiptDeclaredContents,
              (r['description'] ?? '—').toString()),
          _ReceiptLine(
            l10n.courierDeclaredValue,
            r['declared_value'] == null
                ? '—'
                : '${(r['declared_value'] as num).toStringAsFixed(3)} TND',
          ),
          if (r['delivery_mode'] == 'no_code')
            _ReceiptLine(l10n.colisReceiptHandedTo,
                (r['receiver_label'] ?? '—').toString()),
          if (r['driver_name'] != null)
            _ReceiptLine(l10n.driverLabel, r['driver_name'].toString()),
          // La plaque est figée à la prise en charge : un livreur qui la
          // modifie ensuite ne réécrit pas une preuve passée.
          if (r['driver_plate'] != null)
            _ReceiptLine(l10n.colisReceiptPlate, r['driver_plate'].toString()),
          if (r['delivery_distance_m'] != null)
            _ReceiptLine(l10n.colisReceiptDistanceToAddress,
                '${r['delivery_distance_m']} m'),

          if (_pickupUrl != null || _deliveryUrl != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (_pickupUrl != null)
                  Expanded(child: _ProofPhoto(l10n.colisProofPickup, _pickupUrl!)),
                if (_pickupUrl != null && _deliveryUrl != null)
                  const SizedBox(width: 10),
                if (_deliveryUrl != null)
                  Expanded(child: _ProofPhoto(l10n.colisProofDelivery, _deliveryUrl!)),
              ],
            ),
          ],

          if (_disputeEligible) ...[
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 10),
            if (_disputeSent)
              Text(
                l10n.colisDisputeSent,
                style: const TextStyle(fontSize: 12.5, color: Colors.green),
              )
            else ...[
              Text(
                l10n.colisDisputeWindow,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: () =>
                        _openDispute('not_received', l10n.colisDisputeNotReceivedTitle),
                    child: Text(l10n.colisDisputeNotReceived,
                        style: const TextStyle(fontSize: 12.5)),
                  ),
                  OutlinedButton(
                    onPressed: () => _openDispute(
                        'parcel_problem', l10n.colisDisputeProblem),
                    child: Text(l10n.colisDisputeProblem,
                        style: const TextStyle(fontSize: 12.5)),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  bool get _disputeEligible =>
      ColisRepository.canDispute(widget.deliveredAt);
}

/// The 4-digit hand-over code in big letters, with Copy and Share.
class _DeliveryCodeBlock extends StatelessWidget {
  final String code;
  final VoidCallback onShare;

  const _DeliveryCodeBlock({required this.code, required this.onShare});

  @override
  Widget build(BuildContext context) {
    // La consigne passe AU-DESSUS du code et des boutons : lue dans cet ordre,
    // elle dit quoi faire avant de donner la chose à faire. L'ancienne légende
    // sous les boutons répétait la même idée après coup, elle n'est plus là.
    final l10n = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.colisCodeHeadline(code),
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(l10n.colisCodeExplain,
              style: const TextStyle(fontSize: 11.5, color: Colors.black54)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  code,
                  style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 10),
                ),
              ),
              IconButton(
                tooltip: l10n.colisCodeCopy,
                icon: const Icon(Icons.copy_rounded, size: 20),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: code));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.colisCodeCopied)),
                  );
                },
              ),
              IconButton(
                tooltip: l10n.colisCodeShare,
                icon: const Icon(Icons.share_rounded, size: 20),
                onPressed: onShare,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One "label    value" line of the receipt.
class _ReceiptLine extends StatelessWidget {
  final String label;
  final String value;

  const _ReceiptLine(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 128,
            child: Text(label,
                style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

/// A proof photo (pickup / hand-over) with its caption.
class _ProofPhoto extends StatelessWidget {
  final String caption;
  final String url;

  const _ProofPhoto(this.caption, this.url);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(caption,
            style: const TextStyle(fontSize: 11, color: Colors.black54)),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: CachedNetworkImage(
            imageUrl: url,
            height: 110,
            width: double.infinity,
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) => Container(
              height: 110,
              color: const Color(0xFFF0F0F0),
              child: const Center(
                child: Icon(Icons.image_not_supported_outlined, size: 20),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
