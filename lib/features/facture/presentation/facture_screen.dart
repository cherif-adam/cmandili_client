import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/map_address_picker.dart';
import '../../checkout/data/models/delivery_address.dart';
import '../../orders/presentation/order_success_screen.dart';
import '../../bills/services/bill_reminder_service.dart';

// ── Bill types ────────────────────────────────────────────────────────────────

enum _BillType { topnet, steg, sonede, autre }

extension _BillTypeX on _BillType {
  String get label => switch (this) {
        _BillType.topnet => 'Topnet',
        _BillType.steg => 'STEG',
        _BillType.sonede => 'SONEDE',
        _BillType.autre => 'Autre',
      };

  IconData get icon => switch (this) {
        _BillType.topnet => Icons.wifi_rounded,
        _BillType.steg => Icons.bolt_rounded,
        _BillType.sonede => Icons.water_drop_rounded,
        _BillType.autre => Icons.receipt_long_rounded,
      };

  Color get color => switch (this) {
        _BillType.topnet => const Color(0xFF1565C0),
        _BillType.steg => const Color(0xFFF57F17),
        _BillType.sonede => const Color(0xFF00695C),
        _BillType.autre => const Color(0xFF616161),
      };

  String get dbValue => name; // 'topnet' | 'steg' | 'sonede' | 'autre'
}

// ── Screen ────────────────────────────────────────────────────────────────────

class FactureScreen extends ConsumerStatefulWidget {
  final double screenWidth;
  final double screenHeight;

  const FactureScreen({
    super.key,
    required this.screenWidth,
    required this.screenHeight,
  });

  @override
  ConsumerState<FactureScreen> createState() => _FactureScreenState();
}

class _FactureScreenState extends ConsumerState<FactureScreen> {
  static const _orange = Color(0xFFFF9500);
  static const _serviceFee = 5.000;
  static const _tunisianPhone = r'^\d{8}$';

  final _formKey = GlobalKey<FormState>();
  final _referenceController = TextEditingController();
  final _amountController = TextEditingController();
  final _phoneController = TextEditingController();
  final _supabase = Supabase.instance.client;

  _BillType? _selectedBillType;
  DeliveryAddress? _customerAddress;  // pickup (cash collection)
  DeliveryAddress? _officeAddress;    // delivery (where driver pays)
  File? _billPhoto;
  bool _submitting = false;

  @override
  void dispose() {
    _referenceController.dispose();
    _amountController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // ── Photo picker ─────────────────────────────────────────────────────────

  Future<void> _pickPhoto(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1080,
    );
    if (picked != null) {
      setState(() => _billPhoto = File(picked.path));
    }
  }

  void _showPhotoPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Prendre une photo'),
              onTap: () {
                Navigator.pop(context);
                _pickPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Choisir depuis la galerie'),
              onTap: () {
                Navigator.pop(context);
                _pickPhoto(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _selectCustomerAddress() async {
    final address = await Navigator.push<DeliveryAddress>(
      context,
      MaterialPageRoute(
        builder: (_) => const MapAddressPicker(label: 'Votre adresse'),
      ),
    );
    if (address != null) setState(() => _customerAddress = address);
  }

  Future<void> _selectOfficeAddress() async {
    final address = await Navigator.push<DeliveryAddress>(
      context,
      MaterialPageRoute(
        builder: (_) => const MapAddressPicker(label: 'Bureau de paiement'),
      ),
    );
    if (address != null) setState(() => _officeAddress = address);
  }

  Future<String?> _uploadBillPhoto(String userId) async {
    if (_billPhoto == null) return null;
    try {
      final path = '$userId/bill_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final bytes = await _billPhoto!.readAsBytes();
      await _supabase.storage.from('package-photos').uploadBinary(path, bytes);
      return _supabase.storage.from('package-photos').getPublicUrl(path);
    } catch (e) {
      return null;
    }
  }

  // ── Submit ───────────────────────────────────────────────────────────────

  Future<void> _submitRequest() async {
    if (_selectedBillType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner le type de facture')),
      );
      return;
    }
    if (_customerAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez indiquer votre adresse de ramassage')),
      );
      return;
    }
    if (_officeAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez indiquer l\'adresse du bureau')),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw 'Non connecté';

      final billPhotoUrl = await _uploadBillPhoto(user.id);
      final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;

      final result = await _supabase
          .from('orders')
          .insert({
            'user_id': user.id,
            'order_type': 'facture',
            'status': 'ready',
            'pickup_address': _customerAddress!.toJson(),
            'delivery_address': _officeAddress!.toJson(),
            'bill_type': _selectedBillType!.dbValue,
            'bill_reference': _referenceController.text.trim(),
            'bill_amount': amount,
            if (billPhotoUrl != null) 'bill_photo_url': billPhotoUrl,
            'sender_phone': _phoneController.text.trim(),
            'delivery_fee': _serviceFee,
            'subtotal': 0,
            'total': _serviceFee,
            'payment_method': 'cash',
          })
          .select('id')
          .single();

      if (!mounted) return;

      // Schedule a reminder ~28 days from now for the same bill type.
      BillReminderService.instance.scheduleReminder(
        billType: _selectedBillType!.dbValue,
        billLabel: _selectedBillType!.label,
      ).catchError((_) {});

      // push (not pushReplacement) — FactureScreen is an inline sliver on the
      // app's root HomeScreen route, so replacing it here would leave nothing
      // under the tracking screen for "back" to return to.
      final l10n = AppLocalizations.of(context)!;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OrderSuccessScreen(
            orderId: result['id'] as String,
            imageAsset: 'assets/images/amana_facture_hero.jpg',
            title: l10n.factureSuccessTitle,
            trackButtonLabel: l10n.trackMyOrder,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Hero banner ──────────────────────────────────────────────
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 110,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      'assets/images/amana_facture_hero.jpg',
                      fit: BoxFit.cover,
                      alignment: const Alignment(0, 0.2),
                      errorBuilder: (context, error, stackTrace) => const DecoratedBox(
                        decoration: BoxDecoration(gradient: AppColors.primaryGradient),
                      ),
                    ),
                    const DecoratedBox(
                      decoration: BoxDecoration(gradient: AppColors.emeraldBannerGradient),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          AppLocalizations.of(context)!.factureHeroTitle,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: widget.screenWidth * 0.05,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Section: bill type ──────────────────────────────────────
            _sectionTitle('Type de facture'),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.8,
              children: _BillType.values
                  .map((type) => _BillTypeCard(
                        type: type,
                        selected: _selectedBillType == type,
                        onTap: () => setState(() => _selectedBillType = type),
                      ))
                  .toList(),
            ),

            const SizedBox(height: 20),

            // ── Section: bill details ────────────────────────────────────
            _sectionTitle('Détails de la facture'),
            const SizedBox(height: 10),

            TextFormField(
              controller: _referenceController,
              decoration: _inputDeco(
                label: 'Numéro de référence / contrat',
                icon: Icons.tag_rounded,
              ),
              textInputAction: TextInputAction.next,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Obligatoire — numéro de référence';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _amountController,
              decoration: _inputDeco(
                label: 'Montant à payer (TND)',
                icon: Icons.payments_outlined,
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              textInputAction: TextInputAction.next,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Obligatoire — montant de la facture';
                }
                final parsed = double.tryParse(v.trim());
                if (parsed == null || parsed <= 0) {
                  return 'Montant invalide';
                }
                return null;
              },
            ),

            const SizedBox(height: 12),

            // Optional bill photo
            if (_billPhoto != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(
                  _billPhoto!,
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 6),
              TextButton.icon(
                onPressed: () => setState(() => _billPhoto = null),
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('Supprimer la photo'),
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
              ),
            ] else
              OutlinedButton.icon(
                onPressed: _showPhotoPicker,
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Ajouter photo de la facture (optionnel)'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _orange,
                  side: const BorderSide(color: _orange),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),

            const SizedBox(height: 20),

            // ── Section: addresses ───────────────────────────────────────
            _sectionTitle('Votre adresse (ramassage des espèces)'),
            const SizedBox(height: 10),
            _AddressTile(
              address: _customerAddress,
              placeholder: 'Choisir votre adresse',
              icon: Icons.home_outlined,
              onTap: _selectCustomerAddress,
              color: _orange,
            ),
            const SizedBox(height: 16),

            _sectionTitle('Adresse du bureau ${_selectedBillType?.label ?? ''}'),
            const SizedBox(height: 10),
            _AddressTile(
              address: _officeAddress,
              placeholder: 'Choisir l\'adresse du bureau',
              icon: Icons.business_outlined,
              onTap: _selectOfficeAddress,
              color: _orange,
            ),

            const SizedBox(height: 20),

            // ── Section: phone ───────────────────────────────────────────
            _sectionTitle('Votre numéro de téléphone'),
            const SizedBox(height: 10),
            TextFormField(
              controller: _phoneController,
              decoration: _inputDeco(
                label: 'Téléphone (8 chiffres)',
                icon: Icons.phone_rounded,
              ),
              keyboardType: TextInputType.phone,
              maxLength: 8,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textInputAction: TextInputAction.done,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: (v) {
                final val = v?.trim() ?? '';
                if (val.isEmpty) return 'Obligatoire — numéro de téléphone';
                if (!RegExp(_tunisianPhone).hasMatch(val)) {
                  return 'Numéro invalide — exactement 8 chiffres requis';
                }
                return null;
              },
            ),

            const SizedBox(height: 20),

            // ── Section: price summary ───────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _orange.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _orange.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  _PriceRow(
                    label: 'Montant de la facture',
                    value: _amountController.text.isNotEmpty &&
                            double.tryParse(_amountController.text) != null
                        ? '${double.parse(_amountController.text).toStringAsFixed(3)} TND'
                        : '—',
                    note: '(collecté en espèces)',
                  ),
                  const Divider(height: 20),
                  _PriceRow(
                    label: 'Frais de service',
                    value: '${_serviceFee.toStringAsFixed(3)} TND',
                    bold: true,
                    color: _orange,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Submit ───────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submitRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _orange,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _submitting
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 15,
          color: Color(0xFF1A1A2E),
        ),
      );

  InputDecoration _inputDeco({required String label, required IconData icon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20, color: _orange),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _orange, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _BillTypeCard extends StatelessWidget {
  final _BillType type;
  final bool selected;
  final VoidCallback onTap;

  const _BillTypeCard({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: selected ? type.color.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? type.color : Colors.grey.shade200,
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: type.color.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(type.icon, size: 20, color: selected ? type.color : Colors.grey),
            const SizedBox(width: 8),
            Text(
              type.label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: selected ? type.color : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddressTile extends StatelessWidget {
  final DeliveryAddress? address;
  final String placeholder;
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  const _AddressTile({
    required this.address,
    required this.placeholder,
    required this.icon,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final hasAddress = address != null;
    final label = hasAddress
        ? (address!.fullAddress.isNotEmpty ? address!.fullAddress : address!.label)
        : placeholder;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: hasAddress ? color.withValues(alpha: 0.06) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasAddress ? color : Colors.grey.shade300,
            width: hasAddress ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: hasAddress ? color : Colors.grey),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: hasAddress ? const Color(0xFF1A1A2E) : Colors.grey,
                  fontSize: 14,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              hasAddress ? Icons.check_circle_rounded : Icons.chevron_right_rounded,
              color: hasAddress ? color : Colors.grey,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String label;
  final String value;
  final String? note;
  final bool bold;
  final Color? color;

  const _PriceRow({
    required this.label,
    required this.value,
    this.note,
    this.bold = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: bold ? const Color(0xFF1A1A2E) : Colors.grey.shade600,
                  fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
              if (note != null)
                Text(
                  note!,
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 11,
                  ),
                ),
            ],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: bold ? FontWeight.bold : FontWeight.w500,
            fontSize: bold ? 16 : 14,
            color: color ?? const Color(0xFF1A1A2E),
          ),
        ),
      ],
    );
  }
}
