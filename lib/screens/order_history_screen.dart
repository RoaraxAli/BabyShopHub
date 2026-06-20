import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../models/order_model.dart';
import '../services/shop_provider.dart';
import '../services/auth_provider.dart';
import 'order_tracking_screen.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  List<OrderModel> _orders = [];
  bool _loading = true;
  String? _errorMessage;
  StreamSubscription<User?>? _authSubscription;

  @override
  void initState() {
    super.initState();
    // Listen to auth state so we load orders even if currentUser is null at
    // the time initState() runs (common on Flutter Web during session restore).
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        debugPrint('[ORDER HISTORY] Auth state restored — uid: ${user.uid}');
        _loadOrders(user);
      } else {
        debugPrint('[ORDER HISTORY] No authenticated user.');
        if (mounted) {
          setState(() {
            _orders = [];
            _loading = false;
            _errorMessage = null;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadOrders(User user) async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    debugPrint('[ORDER HISTORY] Loading orders for uid: ${user.uid}, email: ${user.email}');

    try {
      // Primary query: by userId field. No orderBy here — composite index not deployed.
      // We sort the results in Dart after fetching.
      final snap = await FirebaseFirestore.instance
          .collection('orders')
          .where('userId', isEqualTo: user.uid)
          .get();

      debugPrint('[ORDER HISTORY] Primary query returned ${snap.docs.length} docs.');

      if (snap.docs.isNotEmpty) {
        final orders = _parseOrders(snap.docs);
        orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        if (mounted) {
          setState(() {
            _orders = orders;
            _loading = false;
          });
        }
        return;
      }

      // Fallback: query by email (for legacy orders or missing userId field)
      if (user.email != null && user.email!.isNotEmpty) {
        debugPrint('[ORDER HISTORY] Primary returned 0; trying email fallback: ${user.email}');
        final emailSnap = await FirebaseFirestore.instance
            .collection('orders')
            .where('email', isEqualTo: user.email)
            .get();

        debugPrint('[ORDER HISTORY] Email fallback returned ${emailSnap.docs.length} docs.');

        final orders = _parseOrders(emailSnap.docs);
        orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        if (mounted) {
          setState(() {
            _orders = orders;
            _loading = false;
          });
        }
        return;
      }

      // No results found
      if (mounted) {
        setState(() {
          _orders = [];
          _loading = false;
        });
      }
    } catch (e, st) {
      debugPrint('[ORDER HISTORY ERROR] Query failed: $e\n$st');
      if (mounted) {
        setState(() {
          _loading = false;
          _errorMessage = 'Failed to load orders. Please try again.';
        });
      }
    }
  }

  List<OrderModel> _parseOrders(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final List<OrderModel> result = [];
    for (final doc in docs) {
      try {
        result.add(OrderModel.fromMap(doc.id, doc.data()));
      } catch (e) {
        debugPrint('[ORDER HISTORY] Failed to parse order ${doc.id}: $e');
      }
    }
    return result;
  }

  void _refresh() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _loadOrders(user);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Pending':
        return Colors.orange;
      case 'Processing':
        return Colors.blue;
      case 'Packed':
        return Colors.indigo;
      case 'Shipped':
        return Colors.teal;
      case 'Out For Delivery':
        return Colors.deepPurple;
      case 'Delivered':
        return Colors.green;
      case 'Cancelled':
        return Colors.redAccent;
      default:
        return Colors.grey;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'Pending':
        return Icons.hourglass_empty_rounded;
      case 'Processing':
        return Icons.settings_rounded;
      case 'Packed':
        return Icons.inventory_2_rounded;
      case 'Shipped':
        return Icons.local_shipping_rounded;
      case 'Out For Delivery':
        return Icons.delivery_dining_rounded;
      case 'Delivered':
        return Icons.check_circle_rounded;
      case 'Cancelled':
        return Icons.cancel_rounded;
      default:
        return Icons.receipt_long_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Orders'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _refresh,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline_rounded, size: 64, color: theme.colorScheme.error.withOpacity(0.5)),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: TextStyle(fontSize: 14, color: theme.colorScheme.error),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _refresh,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _orders.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.receipt_long_outlined, size: 64, color: theme.colorScheme.onSurface.withOpacity(0.2)),
                          const SizedBox(height: 16),
                          Text(
                            'No orders yet',
                            style: TextStyle(fontSize: 16, color: theme.colorScheme.onSurface.withOpacity(0.4)),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Your order history will appear here',
                            style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withOpacity(0.3)),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _orders.length,
                      itemBuilder: (context, index) {
                        final order = _orders[index];
                        return _buildOrderCard(context, order, theme);
                      },
                    ),
    );
  }

  Widget _buildOrderCard(BuildContext context, OrderModel order, ThemeData theme) {
    final statusColor = _statusColor(order.currentStatus);
    final statusIcon = _statusIcon(order.currentStatus);
    final orderId = order.id.length > 8 ? order.id.substring(0, 8).toUpperCase() : order.id.toUpperCase();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => OrderTrackingScreen(order: order)),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00BFA5).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('#$orderId', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF00BFA5))),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 14, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          order.currentStatus,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Items preview
              ...order.items.take(2).map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        item.imageUrl,
                        width: 36,
                        height: 36,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 36, height: 36,
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.child_care_rounded, size: 18),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${item.name} x${item.quantity}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${Provider.of<ShopProvider>(context, listen: false).currencySymbol}${item.totalPrice.toStringAsFixed(2)}',
                      style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withOpacity(0.6)),
                    ),
                  ],
                ),
              )),
              if (order.items.length > 2)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '+${order.items.length - 2} more item${order.items.length - 2 != 1 ? 's' : ''}',
                    style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withOpacity(0.4)),
                  ),
                ),

              const Divider(height: 16),

              if (order.promoCode != null && order.discount > 0) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'Voucher: ${order.promoCode} (-${Provider.of<ShopProvider>(context, listen: false).currencySymbol}${order.discount.toStringAsFixed(2)})',
                      style: const TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
              ],

              // Footer
              Row(
                children: [
                  Text(
                    _formatDate(order.createdAt),
                    style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withOpacity(0.4)),
                  ),
                  const Spacer(),
                  Text(
                    'Total: ${Provider.of<ShopProvider>(context, listen: false).currencySymbol}${order.total.toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Track Order', style: TextStyle(fontSize: 11, color: theme.colorScheme.primary, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 2),
                    Icon(Icons.chevron_right_rounded, size: 16, color: theme.colorScheme.primary),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year} at ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
