import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/order_model.dart';

class OrderTrackingScreen extends StatefulWidget {
  final OrderModel order;

  const OrderTrackingScreen({super.key, required this.order});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  late Stream<DocumentSnapshot<Map<String, dynamic>>> _orderStream;

  @override
  void initState() {
    super.initState();
    _orderStream = FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.order.id)
        .snapshots();
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

  String _formatDate(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year} at ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Track Order'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _orderStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error loading status updates: ${snapshot.error}'));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            // If deleted or not found, fall back to the constructor order state
            return _buildTrackingContent(widget.order, theme);
          }

          final order = OrderModel.fromMap(snapshot.data!.id, snapshot.data!.data()!);
          return _buildTrackingContent(order, theme);
        },
      ),
    );
  }

  Widget _buildTrackingContent(OrderModel order, ThemeData theme) {
    final currentStatus = order.currentStatus;
    final isCancelled = currentStatus == 'Cancelled';

    // We can map all defined statuses to check completion
    final allStatuses = OrderModel.allStatuses.where((s) => s != 'Cancelled').toList();
    final currentStatusIndex = allStatuses.indexOf(currentStatus);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Header Card
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: _statusColor(currentStatus).withOpacity(0.1),
                      child: Icon(_statusIcon(currentStatus), color: _statusColor(currentStatus), size: 30),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Status: $currentStatus',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Order #${order.id.length > 8 ? order.id.substring(0, 8).toUpperCase() : order.id.toUpperCase()}',
                            style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withOpacity(0.5)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Tracking progress bar (horizontal layout for major steps if not cancelled)
            if (!isCancelled) ...[
              const Text(
                'Progress Tracker',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _buildProgressSlider(allStatuses, currentStatusIndex, theme),
              const SizedBox(height: 24),
            ],

            // Detailed Status History Timeline (Vertical)
            const Text(
              'Status History Timeline',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildTimeline(order.statusHistory, theme),

            const SizedBox(height: 24),
            // Shipping Address & Package Info
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.location_on_rounded, color: Color(0xFF00BFA5)),
                        SizedBox(width: 8),
                        Text('Shipping Address', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const Divider(height: 20),
                    Text(
                      order.address,
                      style: const TextStyle(fontSize: 13, height: 1.4),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Items Summary Card
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.shopping_bag_rounded, color: Color(0xFF00BFA5)),
                        SizedBox(width: 8),
                        Text('Order Items', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const Divider(height: 20),
                    ...order.items.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              item.imageUrl,
                              width: 44,
                              height: 44,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 44, height: 44,
                                color: Colors.grey.shade200,
                                child: const Icon(Icons.child_care_rounded, size: 22),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '\$${item.price.toStringAsFixed(2)} x ${item.quantity}',
                                  style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withOpacity(0.5)),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '\$${item.totalPrice.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    )),
                    const Divider(height: 20),
                    if (order.promoCode != null && order.discount > 0) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Promo Code (${order.promoCode})',
                            style: const TextStyle(fontSize: 13, color: Colors.green, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '-\$${order.discount.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 13, color: Colors.green, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Amount', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(
                          '\$${order.total.toStringAsFixed(2)}',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressSlider(List<String> allStatuses, int currentIndex, ThemeData theme) {
    // Determine stages to display on progress bar
    // e.g. Pending -> Processing -> Shipped -> Delivered
    final stages = ['Pending', 'Processing', 'Shipped', 'Delivered'];
    
    // Find index in stages
    int activeStageIdx = 0;
    if (currentIndex >= allStatuses.indexOf('Delivered')) {
      activeStageIdx = 3;
    } else if (currentIndex >= allStatuses.indexOf('Shipped')) {
      activeStageIdx = 2;
    } else if (currentIndex >= allStatuses.indexOf('Processing')) {
      activeStageIdx = 1;
    }

    return Row(
      children: List.generate(stages.length, (index) {
        final isCompleted = index <= activeStageIdx;
        final isLast = index == stages.length - 1;
        
        return Expanded(
          child: Row(
            children: [
              Column(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: isCompleted ? const Color(0xFF00BFA5) : Colors.grey.shade300,
                    child: isCompleted
                        ? const Icon(Icons.check, size: 12, color: Colors.white)
                        : Text((index + 1).toString(), style: const TextStyle(fontSize: 10, color: Colors.black54)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    stages[index],
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isCompleted ? FontWeight.bold : FontWeight.normal,
                      color: isCompleted ? theme.colorScheme.onSurface : Colors.grey,
                    ),
                  ),
                ],
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    height: 2,
                    color: index < activeStageIdx ? const Color(0xFF00BFA5) : Colors.grey.shade300,
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildTimeline(List<OrderStatusHistory> history, ThemeData theme) {
    // Sort timeline so that newest is at the top
    final sorted = List<OrderStatusHistory>.from(history);
    sorted.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sorted.length,
      itemBuilder: (context, index) {
        final item = sorted[index];
        final isLatest = index == 0;
        final color = _statusColor(item.status);
        final isLastItem = index == sorted.length - 1;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Step marker & connecting line
            Column(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isLatest ? color : color.withOpacity(0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 2),
                  ),
                  child: Icon(
                    _statusIcon(item.status),
                    size: 12,
                    color: isLatest ? Colors.white : color,
                  ),
                ),
                if (!isLastItem)
                  Container(
                    width: 2,
                    height: 60,
                    color: Colors.grey.shade300,
                  ),
              ],
            ),
            const SizedBox(width: 16),
            // Details
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          item.status,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isLatest ? color : theme.colorScheme.onSurface.withOpacity(0.8),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _formatDate(item.timestamp),
                          style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withOpacity(0.4)),
                        ),
                      ],
                    ),
                    if (item.note.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.note,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
