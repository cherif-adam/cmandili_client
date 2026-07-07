import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/app_map.dart';
import '../data/models/order.dart';
import '../providers/order_provider.dart';
import '../../loyalty/presentation/loyalty_card_sheet.dart';
import '../../loyalty/presentation/loyalty_cancel_dialog.dart';

class OrderTrackingScreen extends ConsumerStatefulWidget {
  final String orderId;

  /// Set only by the screens that just created this order (checkout,
  /// courier, facture) — gates the one-time loyalty sheet so it never
  /// reappears when an old order is reopened from history/home.
  final bool justPlaced;

  const OrderTrackingScreen({
    super.key,
    required this.orderId,
    this.justPlaced = false,
  });

  @override
  ConsumerState<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends ConsumerState<OrderTrackingScreen> {
  final AppMapController _mapController = AppMapController();
  double? _driverLat;
  double? _driverLng;
  StreamSubscription? _deliverySubscription;
  List<({double lat, double lng})>? _routePolyline;
  bool _routeFetched = false;
  bool _loyaltySheetScheduled = false;
  final _supabase = Supabase.instance.client;


  @override
  void initState() {
    super.initState();
    _subscribeToDelivery();
  }

  void _maybeScheduleLoyaltySheet(Order order) {
    if (!widget.justPlaced || _loyaltySheetScheduled) return;
    _loyaltySheetScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      LoyaltyCardSheet.maybeShow(context, ref: ref, order: order);
    });
  }

  void _subscribeToDelivery() {
    _deliverySubscription = _supabase
        .from('deliveries')
        .stream(primaryKey: ['id'])
        .eq('order_id', widget.orderId)
        .listen((rows) {
          if (!mounted) return;
          if (rows.isNotEmpty) {
            final newLat = (rows.first['current_lat'] as num?)?.toDouble();
            final newLng = (rows.first['current_lng'] as num?)?.toDouble();
            setState(() {
              _driverLat = newLat;
              _driverLng = newLng;
            });
            if (_driverLat != null && _driverLng != null) {
              _mapController.animateToPoint(_driverLat!, _driverLng!);
            }
          }
        });
  }

  /// Fetch a route polyline from the Mapbox Directions API and draw it on the
  /// map. Called once when driver location first becomes available.
  ///
  /// We request `geometries=geojson` so the response contains an already-decoded
  /// list of [lng, lat] pairs — no encoded-polyline decoding needed.
  Future<void> _fetchRoute({
    required ({double lat, double lng}) origin,
    required ({double lat, double lng}) destination,
  }) async {
    final token = dotenv.env['MAPBOX_PUBLIC_TOKEN'] ?? '';
    final url = Uri.parse(
      'https://api.mapbox.com/directions/v5/mapbox/driving/'
      '${origin.lng},${origin.lat};${destination.lng},${destination.lat}'
      '?geometries=geojson&overview=full&access_token=$token',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode != 200) return;
      final data = json.decode(response.body) as Map<String, dynamic>;
      final routes = data['routes'] as List?;
      if (routes == null || routes.isEmpty) return;

      final coords = routes.first['geometry']['coordinates'] as List;
      final points = <({double lat, double lng})>[
        for (final c in coords)
          (
            lat: (c[1] as num).toDouble(),
            lng: (c[0] as num).toDouble(),
          ),
      ];

      if (!mounted) return;
      setState(() => _routePolyline = points);
    } catch (e) {
      debugPrint('Route fetch failed: $e');
    }
  }

  @override
  void dispose() {
    _deliverySubscription?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  static const _cancelReasons = [
    'Erreur de commande',
    'Délai trop long',
    "J'ai changé d'avis",
    'Autre',
  ];

  Future<void> _showCancelDialog(Order order) async {
    String? selectedReason;
    final hasDriver = order.driverId != null;

    final confirmed = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text(
              'Annuler la commande',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasDriver)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.orange.shade300),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              color: Colors.orange.shade700, size: 20),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Un livreur est déjà assigné à votre commande. '
                              'Voulez-vous vraiment annuler ?',
                              style: TextStyle(fontSize: 13, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const Text(
                    "Raison de l'annulation :",
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  ..._cancelReasons.map(
                    (r) => RadioListTile<String>(
                      title: Text(r, style: const TextStyle(fontSize: 14)),
                      value: r,
                      groupValue: selectedReason,
                      dense: true,
                      activeColor: AppColors.primary,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) => setDlgState(() => selectedReason = val),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Retour'),
              ),
              ElevatedButton(
                onPressed: selectedReason == null
                    ? null
                    : () => Navigator.pop(ctx, selectedReason),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Confirmer'),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed == null || !mounted) return;

    final success = await ref
        .read(orderRepositoryProvider)
        .cancelOrderByCustomer(widget.orderId, confirmed);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Commande annulée avec succès.'),
          backgroundColor: Colors.red,
        ),
      );
      final reordered = await LoyaltyCancelDialog.maybeShow(context, ref: ref, order: order);
      if (!mounted) return;
      if (reordered) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      } else {
        Navigator.pop(context);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Impossible d\'annuler — la commande est déjà en cours de préparation.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _confirmReceipt() async {
    await ref
        .read(orderRepositoryProvider)
        .updateOrderStatus(widget.orderId, OrderStatus.delivered);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.orderMarkedDelivered),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderAsync = ref.watch(orderStreamProvider(widget.orderId));

    return orderAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        body: Center(child: Text('Error loading order: $e')),
      ),
      data: (order) {
        _maybeScheduleLoyaltySheet(order);
        return _buildTracking(order);
      },
    );
  }

  Widget _buildTracking(Order order) {
    final isCourier = order.type == OrderType.courier;
    final isFacture = order.type == OrderType.facture;
    final showMap = (order.status == OrderStatus.onTheWay || order.status == OrderStatus.pickedUp) &&
        _driverLat != null &&
        _driverLng != null;

    // Fetch route once when driver location first becomes available.
    // For facture: when driver is going to customer (onTheWay → pickupAddress)
    // or going to office (pickedUp → deliveryAddress).
    if (showMap && !_routeFetched) {
      _routeFetched = true;
      final destination = isFacture && order.status == OrderStatus.onTheWay && order.pickupAddress != null
          ? (lat: order.pickupAddress!.latitude, lng: order.pickupAddress!.longitude)
          : (lat: order.deliveryAddress.latitude, lng: order.deliveryAddress.longitude);
      _fetchRoute(
        origin: (lat: _driverLat!, lng: _driverLng!),
        destination: destination,
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // Map
          if (showMap)
            AppMap(
              controller: _mapController,
              initialLatitude: order.deliveryAddress.latitude,
              initialLongitude: order.deliveryAddress.longitude,
              initialZoom: 14,
              polyline: _routePolyline,
              markers: {
                AppMapMarker(
                  id: 'delivery',
                  latitude: order.deliveryAddress.latitude,
                  longitude: order.deliveryAddress.longitude,
                  kind: AppMapMarkerKind.delivery,
                  title: isFacture ? 'Bureau de paiement' : 'Delivery Location',
                ),
                if ((isCourier || isFacture) && order.pickupAddress != null)
                  AppMapMarker(
                    id: 'pickup',
                    latitude: order.pickupAddress!.latitude,
                    longitude: order.pickupAddress!.longitude,
                    kind: AppMapMarkerKind.pickup,
                    title: isFacture ? 'Votre adresse' : 'Pickup Location',
                  ),
                AppMapMarker(
                  id: 'driver',
                  latitude: _driverLat!,
                  longitude: _driverLng!,
                  kind: AppMapMarkerKind.driver,
                  title: order.driverName ?? 'Driver',
                ),
              },
            )
          else
            Container(
              color: AppColors.background,
              child: Center(
                child: Icon(
                  isFacture
                      ? Icons.receipt_long_rounded
                      : isCourier
                          ? Icons.local_shipping
                          : Icons.restaurant,
                  size: 100,
                  color: AppColors.textLight.withValues(alpha: 0.3),
                ),
              ),
            ),

          // Top Bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Sheet
          DraggableScrollableSheet(
            initialChildSize: 0.45,
            minChildSize: 0.4,
            maxChildSize: 0.9,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.textLight.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    Text(
                      order.getStatusText(),
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),

                    if (order.estimatedDeliveryTime != null)
                      Text(
                        'Estimated delivery: ${_formatTime(order.estimatedDeliveryTime!)}',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                      ),

                    if (order.status == OrderStatus.delivered &&
                        order.loyaltyMilestoneType != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.celebration, color: Colors.green),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                order.loyaltyMilestoneType == 'free'
                                    ? '🎉 Livraison gratuite appliquée — merci de votre fidélité !'
                                    : '🎉 -50% sur la livraison appliqué — merci de votre fidélité !',
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Confirm receipt button for courier
                    if (isCourier &&
                        order.status == OrderStatus.onTheWay &&
                        !order.isRecipientAccepted)
                      Container(
                        margin: const EdgeInsets.only(bottom: 24),
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _confirmReceipt,
                          icon: const Icon(Icons.check_circle_outline),
                          label: Text(AppLocalizations.of(context)!.confirmReceipt),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.secondary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.all(16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),

                    if (order.isRecipientAccepted)
                      Container(
                        margin: const EdgeInsets.only(bottom: 24),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.success),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle, color: AppColors.success),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                AppLocalizations.of(context)!.recipientAccepted,
                                style: const TextStyle(
                                  color: AppColors.success,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    _OrderTimeline(status: order.status, isCourier: isCourier, isFacture: isFacture),

                    const SizedBox(height: 24),

                    // Driver Info
                    if ((order.status == OrderStatus.onTheWay ||
                            order.status == OrderStatus.pickedUp) &&
                        order.driverName != null) ...[
                      Text(
                        AppLocalizations.of(context)!.yourCourier,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const CircleAvatar(
                              radius: 30,
                              backgroundColor: AppColors.primary,
                              child: Icon(Icons.person, color: Colors.white, size: 30),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    order.driverName!,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  Text(
                                    order.driverPhone ?? '',
                                    style: const TextStyle(
                                        color: AppColors.textSecondary, fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => _callPhone(context, order.driverPhone),
                              icon: const Icon(Icons.phone, color: AppColors.primary),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Order Details
                    Text(
                      isFacture
                          ? 'Détails de la facture'
                          : isCourier
                              ? AppLocalizations.of(context)!.packageDetails
                              : 'Order Details',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),

                    if (isFacture) ...[
                      _DetailRow(label: 'Type', value: _billTypeLabel(order.billType)),
                      _DetailRow(label: 'Référence', value: order.billReference ?? 'N/A'),
                      _DetailRow(label: 'Montant', value: order.billAmount != null ? '${order.billAmount!.toStringAsFixed(3)} TND' : 'N/A'),
                      if (order.senderPhone != null)
                        _DetailRow(label: 'Téléphone', value: order.senderPhone!),
                      const SizedBox(height: 16),
                      // Show bill photo if customer uploaded one
                      if (order.billPhotoUrl != null) ...[
                        const Text('Photo de la facture', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () => _showFullScreenImage(context, order.billPhotoUrl!),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              order.billPhotoUrl!,
                              height: 140,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      // Show receipt photo if driver uploaded one
                      if (order.billReceiptUrl != null) ...[
                        const Text('Reçu de paiement', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.success)),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () => _showFullScreenImage(context, order.billReceiptUrl!),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              order.billReceiptUrl!,
                              height: 140,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ] else if (isCourier) ...[
                      _DetailRow(label: AppLocalizations.of(context)!.recipient, value: order.recipientName ?? 'N/A'),
                      _DetailRow(label: AppLocalizations.of(context)!.phone, value: order.recipientPhone ?? 'N/A'),
                      _DetailRow(label: AppLocalizations.of(context)!.item, value: order.packageDescription ?? 'Package'),
                      const SizedBox(height: 16),
                    ] else ...[
                      Text(
                        order.restaurantName,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      ...order.items.map((item) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('${item.quantity}x ${item.name}',
                                    style:
                                        const TextStyle(color: AppColors.textSecondary)),
                                Text(CurrencyFormatter.formatPrice(item.totalPrice),
                                    style:
                                        const TextStyle(color: AppColors.textSecondary)),
                              ],
                            ),
                          )),
                    ],

                    const Divider(height: 24),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(AppLocalizations.of(context)!.total,
                            style:
                                const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text(
                          CurrencyFormatter.formatPrice(order.total),
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    Row(
                      children: [
                        const Icon(Icons.payments_outlined,
                            size: 20, color: AppColors.textSecondary),
                        const SizedBox(width: 8),
                        Text(order.paymentMethod,
                            style: const TextStyle(color: AppColors.textSecondary)),
                      ],
                    ),

                    // ── Cancellation section ──────────────────────────────
                    if (order.status == OrderStatus.pending ||
                        order.status == OrderStatus.confirmed) ...[
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _showCancelDialog(order),
                          icon: const Icon(Icons.cancel_outlined,
                              color: Colors.red, size: 18),
                          label: const Text(
                            'Annuler la commande',
                            style: TextStyle(color: Colors.red),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ] else if (order.status != OrderStatus.cancelled &&
                        order.status != OrderStatus.delivered &&
                        order.status.index >= OrderStatus.pickedUp.index) ...[
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline,
                                size: 18, color: AppColors.textSecondary),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'La commande est déjà en route. '
                                'Pour annuler, contactez le support.',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  String _billTypeLabel(String? billType) {
    switch (billType) {
      case 'steg': return 'STEG (Électricité)';
      case 'sonede': return 'SONEDE (Eau)';
      case 'topnet': return 'Topnet (Internet)';
      case 'autre': return 'Autre';
      default: return billType ?? 'N/A';
    }
  }

  void _showFullScreenImage(BuildContext context, String url) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: InteractiveViewer(
              child: Image.network(url, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final difference = time.difference(DateTime.now());
    if (difference.inMinutes < 60) return '${difference.inMinutes} minutes';
    return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _callPhone(BuildContext context, String? phone) async {
    final number = phone?.trim();
    if (number == null || number.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.driverPhoneNotAvailable)),
      );
      return;
    }
    final uri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.unableToStartCall)),
      );
    }
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _OrderTimeline extends StatelessWidget {
  final OrderStatus status;
  final bool isCourier;
  final bool isFacture;

  const _OrderTimeline({required this.status, this.isCourier = false, this.isFacture = false});

  @override
  Widget build(BuildContext context) {
    final steps = isFacture
        ? [
            _TimelineStep(
              title: 'Commande confirmée',
              isCompleted: status.index >= OrderStatus.confirmed.index,
              icon: Icons.check_circle,
            ),
            _TimelineStep(
              title: 'Livreur en route chez vous',
              isCompleted: status.index >= OrderStatus.onTheWay.index,
              icon: Icons.directions_bike,
            ),
            _TimelineStep(
              title: 'Espèces collectées',
              isCompleted: status.index >= OrderStatus.pickedUp.index,
              icon: Icons.payments_rounded,
            ),
            _TimelineStep(
              title: 'Facture payée',
              isCompleted: status.index >= OrderStatus.delivered.index,
              icon: Icons.receipt_long_rounded,
            ),
          ]
        : isCourier
        ? [
            _TimelineStep(
              title: 'Request Confirmed',
              isCompleted: status.index >= OrderStatus.confirmed.index,
              icon: Icons.check_circle,
            ),
            _TimelineStep(
              title: 'Picked Up',
              isCompleted: status.index >= OrderStatus.pickedUp.index ||
                  status == OrderStatus.onTheWay ||
                  status == OrderStatus.delivered,
              icon: Icons.inventory_2,
            ),
            _TimelineStep(
              title: 'On the Way',
              isCompleted: status.index >= OrderStatus.onTheWay.index,
              icon: Icons.local_shipping,
            ),
            _TimelineStep(
              title: 'Delivered',
              isCompleted: status.index >= OrderStatus.delivered.index,
              icon: Icons.done_all,
            ),
          ]
        : [
            _TimelineStep(
              title: 'Order Confirmed',
              isCompleted: status.index >= OrderStatus.confirmed.index,
              icon: Icons.check_circle,
            ),
            _TimelineStep(
              title: 'Preparing',
              isCompleted: status.index >= OrderStatus.preparing.index,
              icon: Icons.restaurant,
            ),
            _TimelineStep(
              title: 'On the Way',
              isCompleted: status.index >= OrderStatus.onTheWay.index,
              icon: Icons.delivery_dining,
            ),
            _TimelineStep(
              title: 'Delivered',
              isCompleted: status.index >= OrderStatus.delivered.index,
              icon: Icons.done_all,
            ),
          ];

    return Column(
      children: List.generate(
        steps.length,
        (index) => _TimelineItem(step: steps[index], isLast: index == steps.length - 1),
      ),
    );
  }
}

class _TimelineStep {
  final String title;
  final bool isCompleted;
  final IconData icon;

  _TimelineStep({required this.title, required this.isCompleted, required this.icon});
}

class _TimelineItem extends StatelessWidget {
  final _TimelineStep step;
  final bool isLast;

  const _TimelineItem({required this.step, required this.isLast});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: step.isCompleted ? AppColors.primary : AppColors.background,
                shape: BoxShape.circle,
                border: Border.all(
                  color: step.isCompleted ? AppColors.primary : AppColors.textLight,
                  width: 2,
                ),
              ),
              child: Icon(
                step.icon,
                color: step.isCompleted ? Colors.white : AppColors.textLight,
                size: 20,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 40,
                color: step.isCompleted
                    ? AppColors.primary
                    : AppColors.textLight.withValues(alpha: 0.3),
              ),
          ],
        ),
        const SizedBox(width: 16),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            step.title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: step.isCompleted ? FontWeight.w600 : FontWeight.normal,
              color: step.isCompleted ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
