import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../models/order_model.dart';
import '../services/shop_provider.dart';
import '../services/auth_provider.dart';
import 'auth/login_screen.dart';

class DeliveryPanel extends StatefulWidget {
  const DeliveryPanel({super.key});

  @override
  State<DeliveryPanel> createState() => _DeliveryPanelState();
}

class _DeliveryPanelState extends State<DeliveryPanel> {
  String _generateOTP() {
    final rand = Random();
    return (1000 + rand.nextInt(9000)).toString(); // 4 digit OTP
  }

  Future<void> _startDelivery(OrderModel order, String driverId) async {
    try {
      final otp = _generateOTP();
      
      final newHistory = List<OrderStatusHistory>.from(order.statusHistory)
        ..add(OrderStatusHistory(
          status: 'Out For Delivery',
          timestamp: DateTime.now(),
          note: 'Assigned to driver $driverId',
        ));

      await FirebaseFirestore.instance.collection('orders').doc(order.id).update({
        'driverId': driverId,
        'deliveryOTP': otp,
        'statusHistory': newHistory.map((h) => h.toMap()).toList(),
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Delivery Started!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start delivery: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _completeDelivery(OrderModel order) async {
    final otpCtrl = TextEditingController();
    bool error = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) {
          return AlertDialog(
            title: const Text('Verify Delivery OTP', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Ask the customer for the 4-digit Delivery OTP shown in their app to complete the delivery.', style: TextStyle(fontSize: 13)),
                const SizedBox(height: 16),
                TextField(
                  controller: otpCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  decoration: InputDecoration(
                    labelText: 'Enter 4-digit OTP',
                    errorText: error ? 'Incorrect OTP' : null,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  if (otpCtrl.text == order.deliveryOTP) {
                    Navigator.pop(ctx, true);
                  } else {
                    setStateDialog(() => error = true);
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00BFA5), foregroundColor: Colors.white),
                child: const Text('Verify & Complete'),
              ),
            ],
          );
        }
      ),
    ).then((success) async {
      if (success == true) {
        final newHistory = List<OrderStatusHistory>.from(order.statusHistory)
          ..add(OrderStatusHistory(
            status: 'Delivered',
            timestamp: DateTime.now(),
            note: 'Delivered and verified via OTP.',
          ));

        await FirebaseFirestore.instance.collection('orders').doc(order.id).update({
          'statusHistory': newHistory.map((h) => h.toMap()).toList(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Order successfully delivered!'), backgroundColor: Colors.green),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final driverId = Provider.of<AuthProvider>(context, listen: false).currentUser?.uid ?? '';

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Delivery Dashboard'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout_rounded),
              onPressed: () async {
                await Provider.of<AuthProvider>(context, listen: false).logout();
                if (mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                }
              },
            )
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Available Orders'),
              Tab(text: 'My Deliveries'),
            ],
            indicatorColor: Theme.of(context).colorScheme.primary,
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: Colors.black54,
          ),
        ),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('orders').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

            final allOrders = snapshot.data!.docs
                .map((doc) => OrderModel.fromMap(doc.id, doc.data()))
                .toList()
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

            // Available: Packed or Shipped and not assigned to anyone yet (or assigned to no one)
            final availableOrders = allOrders.where((o) => 
                (o.currentStatus == 'Packed' || o.currentStatus == 'Shipped') && 
                (o.driverId == null || o.driverId!.isEmpty)).toList();

            // My Deliveries: Out For Delivery and assigned to this driver
            final myDeliveries = allOrders.where((o) => 
                o.currentStatus == 'Out For Delivery' && 
                o.driverId == driverId).toList();

            return TabBarView(
              children: [
                _buildOrderList(availableOrders, true, driverId),
                _buildOrderList(myDeliveries, false, driverId),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildOrderList(List<OrderModel> orders, bool isAvailable, String driverId) {
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_rounded, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(isAvailable ? 'No available orders to deliver right now.' : 'You have no active deliveries.', 
              style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Order #${order.id.substring(0, 8).toUpperCase()}', 
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isAvailable ? Colors.blue.shade100 : Colors.deepPurple.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        order.currentStatus,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, 
                          color: isAvailable ? Colors.blue.shade700 : Colors.deepPurple.shade700),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  children: [
                    const Icon(Icons.location_on_rounded, size: 20, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(child: Text(order.address, style: const TextStyle(fontSize: 14))),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.shopping_bag_rounded, size: 20, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(child: Text('${order.items.length} items • ${Provider.of<ShopProvider>(context, listen: false).currencySymbol}${order.total.toStringAsFixed(2)}', 
                      style: const TextStyle(fontSize: 14))),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: Icon(isAvailable ? Icons.local_shipping_rounded : Icons.verified_user_rounded),
                    label: Text(isAvailable ? 'Start Delivery' : 'Enter OTP to Complete'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: isAvailable ? Colors.blue : const Color(0xFF00BFA5),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      if (isAvailable) {
                        _startDelivery(order, driverId);
                      } else {
                        _completeDelivery(order);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
