import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/shop_provider.dart';
import '../services/auth_provider.dart';
import '../widgets/animated_loader.dart';
import '../models/user.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();
  final _cardNameController = TextEditingController();
  final _cardNumberController = TextEditingController();
  final _cardExpiryController = TextEditingController();
  final _cardCvvController = TextEditingController();
  final _promoController = TextEditingController();
  String? _promoError;

  @override
  void dispose() {
    _addressController.dispose();
    _cardNameController.dispose();
    _cardNumberController.dispose();
    _cardExpiryController.dispose();
    _cardCvvController.dispose();
    _promoController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final addresses = auth.currentUser?.addresses ?? [];
      if (addresses.isNotEmpty) {
        final defaultAddr = addresses.firstWhere(
          (a) => a.isDefault,
          orElse: () => addresses.first,
        );
        _addressController.text = _formatAddress(defaultAddr);
      }
    });
  }

  String _formatAddress(UserAddress addr) {
    final secondLine = addr.addressLine2 != null && addr.addressLine2!.isNotEmpty ? ', ${addr.addressLine2}' : '';
    return '${addr.recipientName}\n${addr.addressLine1}$secondLine\n${addr.city}, ${addr.postalCode}\nPhone: ${addr.phone}';
  }

  void _showSavedAddressesPicker(BuildContext context, AuthProvider auth) {
    final addresses = auth.currentUser?.addresses ?? [];

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Select Shipping Address'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: addresses.length,
              itemBuilder: (context, index) {
                final addr = addresses[index];
                return ListTile(
                  title: Text(addr.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${addr.recipientName}, ${addr.addressLine1}, ${addr.city}'),
                  trailing: addr.isDefault ? const Icon(Icons.check_circle_rounded, color: Colors.green) : null,
                  onTap: () {
                    setState(() {
                      _addressController.text = _formatAddress(addr);
                    });
                    Navigator.of(context).pop();
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handlePayment() async {
    if (!_formKey.currentState!.validate()) return;

    final shop = Provider.of<ShopProvider>(context, listen: false);
    final auth = Provider.of<AuthProvider>(context, listen: false);

    final userEmail = auth.currentUser?.email ?? 'guest.parent@gmail.com';
    // Bypassing Stripe to directly process the checkout locally in Firestore
    final errorMsg = await shop.processCheckout(userEmail, _addressController.text.trim());

    if (!mounted) return;

    if (errorMsg == null) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order placed successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Checkout failed: $errorMsg'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shop = Provider.of<ShopProvider>(context);
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Secure Checkout'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: shop.isLoading
          ? const Center(
              child: AnimatedLoader(
                size: 80,
                message: 'Processing secure payment...',
              ),
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20.0),
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Shipping Details',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      if (auth.currentUser?.addresses.isNotEmpty ?? false)
                        TextButton.icon(
                          icon: const Icon(Icons.location_on_rounded, size: 16),
                          label: const Text('Select Saved'),
                          onPressed: () => _showSavedAddressesPicker(context, auth),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _addressController,
                    maxLines: 3,
                    validator: (val) => val == null || val.trim().isEmpty ? 'Enter shipping address' : null,
                    decoration: const InputDecoration(
                      labelText: 'Delivery Address',
                      prefixIcon: Icon(Icons.home_outlined),
                      hintText: 'Recipient Name\n123 Sweet Baby Lane, Nursery City\nPhone: ...',
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Promo Code Application Row
                  const Text(
                    'Promo Code / Coupon',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  if (shop.appliedPromoCode != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_outline_rounded, color: Colors.green.shade700, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Code "${shop.appliedPromoCode}" Applied!',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade800,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  shop.appliedPromoCode == 'FIRSTBABY'
                                      ? '15% discount successfully subtracted.'
                                      : shop.appliedPromoCode == 'NEWPARENT'
                                          ? '20% discount successfully subtracted.'
                                          : 'Flat ${shop.currencySymbol}10.00 discount successfully subtracted.',
                                  style: TextStyle(
                                    color: Colors.green.shade700,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close_rounded, color: Colors.green.shade800),
                            onPressed: () {
                              shop.removePromoCode();
                              _promoController.clear();
                              setState(() {
                                _promoError = null;
                              });
                            },
                          ),
                        ],
                      ),
                    )
                  else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _promoController,
                            onChanged: (val) {
                              if (_promoError != null) {
                                setState(() {
                                  _promoError = null;
                                });
                              }
                            },
                            decoration: InputDecoration(
                              labelText: 'Coupon Code',
                              hintText: 'e.g. FIRSTBABY',
                              prefixIcon: const Icon(Icons.card_giftcard_rounded),
                              errorText: _promoError,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: () {
                              final error = shop.applyPromoCode(_promoController.text);
                              if (error != null) {
                                setState(() {
                                  _promoError = error;
                                });
                              } else {
                                setState(() {
                                  _promoError = null;
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Coupon code applied successfully!'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text('Apply'),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 24),

                  // Order Total Summary card
                  Card(
                    color: theme.colorScheme.primary.withValues(alpha: 0.04),
                    elevation: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Cart Subtotal:', style: TextStyle(fontSize: 14)),
                              Text('${shop.currencySymbol}${shop.cartSubtotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                          if (shop.promoDiscount > 0) ...[
                            const Divider(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Discount (${shop.appliedPromoCode}):', style: const TextStyle(fontSize: 14, color: Colors.green)),
                                Text('-${shop.currencySymbol}${shop.promoDiscount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                              ],
                            ),
                          ],
                          const Divider(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: const [
                              Text('Delivery Shipping:', style: TextStyle(fontSize: 14)),
                              Text('FREE', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                            ],
                          ),
                          const Divider(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Grand Total:',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '${shop.currencySymbol}${shop.cartTotal.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  ElevatedButton(
                    onPressed: _handlePayment,
                    child: const Text('Complete Order'),
                  ),
                ],
              ),
            ),
    );
  }
}
