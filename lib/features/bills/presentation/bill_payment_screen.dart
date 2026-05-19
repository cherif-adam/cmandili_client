import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/delivery_fee.dart';
import '../data/models/bill_provider.dart';
import '../../orders/presentation/order_tracking_screen.dart';
import '../../checkout/presentation/address_selection_screen.dart';
import '../../checkout/data/models/delivery_address.dart';

class BillPaymentScreen extends StatefulWidget {
  const BillPaymentScreen({super.key});

  @override
  State<BillPaymentScreen> createState() => _BillPaymentScreenState();
}

class _BillPaymentScreenState extends State<BillPaymentScreen> {
  BillCategory _selectedCategory = BillCategory.internet;
  BillProvider? _selectedProvider;
  final _amountController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }



  void _handleRequest() {
    if (_formKey.currentState!.validate() && _selectedProvider != null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(AppLocalizations.of(context)!.confirmPickupRequest),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'A driver will come to collect cash for your ${_selectedProvider!.name} bill.',
                style: TextStyle(color: Colors.grey[700]),
              ),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context)!.amountToCollect,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              Text(
                '${_amountController.text} DT',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                  color: AppColors.primary,
                ),
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
                Navigator.pop(context); // Close confirmation
                _createAndTrackOrder(); // async, runs in background
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: Text(AppLocalizations.of(context)!.confirmPickup),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _createAndTrackOrder() async {
    final amount = double.parse(_amountController.text);
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.pleaseSignInToContinue), backgroundColor: AppColors.error),
        );
      }
      return;
    }

    // Ask user to select their address
    final address = await Navigator.push<DeliveryAddress>(
      context,
      MaterialPageRoute(builder: (_) => const AddressSelectionScreen()),
    );
    if (address == null || !mounted) return;

    try {
      // Bills have no pickup location (driver just collects cash at the
      // customer's address), so no distance bonus applies. Still enforce
      // the 3 DT floor — old hardcoded 2 DT was below the agreed minimum.
      final deliveryFee = calculateDeliveryFee(partnerFlatFee: 2.0);

      final response = await supabase.from('orders').insert({
        'user_id': userId,
        'status': 'pending',
        'subtotal': amount,
        'delivery_fee': deliveryFee,
        'total': amount + deliveryFee,
        'payment_method': 'cash',
        'notes': 'Bill Payment: ${_selectedProvider!.name} (${_selectedCategory.name})',
        'delivery_address': address.toJson(),
        'order_type': 'billPayment',
        'estimated_delivery_time': DateTime.now().add(const Duration(minutes: 30)).toIso8601String(),
      }).select('id').single();

      final orderId = response['id'] as String;

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OrderTrackingScreen(orderId: orderId),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create order: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredProviders = BillProvider.providers
        .where((p) => p.category == _selectedCategory)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)!.billPayments,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category Tabs
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    _buildTab(AppLocalizations.of(context)!.internet, BillCategory.internet),
                    _buildTab(AppLocalizations.of(context)!.electricity, BillCategory.electricity),
                    _buildTab(AppLocalizations.of(context)!.water, BillCategory.water),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Providers Selection
              Text(
                AppLocalizations.of(context)!.selectProvider,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              
              if (filteredProviders.isEmpty)
                Container(
                  padding: const EdgeInsets.all(32),
                  alignment: Alignment.center,
                  child: Text(
                    AppLocalizations.of(context)!.noProvidersAvailable,
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                )
              else
                SizedBox(
                  height: 120,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: filteredProviders.length,
                    separatorBuilder: (context, index) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final provider = filteredProviders[index];
                      final isSelected = _selectedProvider?.id == provider.id;
                      
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedProvider = provider;
                          });
                        },
                        child: Container(
                          width: 100,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected 
                                  ? Color(int.parse(provider.colorHex.replaceFirst('#', '0xFF')))
                                  : Colors.grey.shade300,
                              width: 2,
                            ),
                            boxShadow: [
                              if (isSelected)
                                BoxShadow(
                                  color: Color(int.parse(provider.colorHex.replaceFirst('#', '0xFF'))).withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                provider.icon,
                                style: const TextStyle(fontSize: 32),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                provider.name,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected 
                                      ? Color(int.parse(provider.colorHex.replaceFirst('#', '0xFF')))
                                      : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

              if (_selectedProvider != null) ...[
                const SizedBox(height: 32),
                Text(
                  AppLocalizations.of(context)!.howMuchToPay,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  AppLocalizations.of(context)!.driverWillCollect,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 16),
                
                // Amount Input
                TextFormField(
                  controller: _amountController,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.amountDt,
                    hintText: '0.000',
                    prefixIcon: const Icon(Icons.attach_money),
                    suffixText: 'DT',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return AppLocalizations.of(context)!.pleaseEnterAmount;
                    }
                    final amount = double.tryParse(value);
                    if (amount == null || amount <= 0) {
                      return AppLocalizations.of(context)!.pleaseEnterValidAmount;
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 32),
                
                // Request Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _handleRequest,
                    icon: const Icon(Icons.delivery_dining, size: 28),
                    label: Text(
                      AppLocalizations.of(context)!.requestDriverForPickup,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    AppLocalizations.of(context)!.serviceFeeNote,
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTab(String label, BillCategory category) {
    final isSelected = _selectedCategory == category;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedCategory = category;
            _selectedProvider = null; // Reset selection when changing category
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? Colors.black : Colors.grey[600],
            ),
          ),
        ),
      ),
    );
  }
}
