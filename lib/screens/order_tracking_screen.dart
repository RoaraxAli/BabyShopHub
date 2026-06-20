import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/shop_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/order_model.dart';
import '../models/product.dart';
import 'product_details_screen.dart';

class OrderTrackingScreen extends StatefulWidget {
  final OrderModel order;

  const OrderTrackingScreen({super.key, required this.order});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}
class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  late Stream<DocumentSnapshot<Map<String, dynamic>>> _orderStream;
  LatLng? _destinationLocation;
  bool _isLoadingMap = true;

  @override
  void initState() {
    super.initState();
    _geocodeAddress();
    _orderStream = FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.order.id)
        .snapshots();
  }

  Future<void> _geocodeAddress() async {
    try {
      final query = Uri.encodeComponent(widget.order.address);
      final url = 'https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=1';
      final response = await http.get(Uri.parse(url), headers: {'User-Agent': 'BabyShopHubApp'});
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List && data.isNotEmpty) {
          final lat = double.parse(data[0]['lat'].toString());
          final lon = double.parse(data[0]['lon'].toString());
          if (mounted) {
            setState(() {
              _destinationLocation = LatLng(lat, lon);
              _isLoadingMap = false;
            });
          }
          return;
        }
      }
    } catch (e) {
      debugPrint('Geocoding error: $e');
    }
    
    // Fallback: Default to a generic location
    if (mounted) {
      setState(() {
        _destinationLocation = const LatLng(37.7749, -122.4194);
        _isLoadingMap = false;
      });
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

            // Map View
            if (currentStatus != 'Cancelled' && currentStatus != 'Pending')
              _buildMapView(order),
              
            // Delivery OTP View
            if (currentStatus == 'Out For Delivery' && order.deliveryOTP != null)
              _buildOTPView(order),

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
                    ...order.items.map((item) {
                      final shop = Provider.of<ShopProvider>(context, listen: false);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
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
                                        '${shop.currencySymbol}${item.price.toStringAsFixed(2)} x ${item.quantity}',
                                        style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withOpacity(0.5)),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '${shop.currencySymbol}${item.totalPrice.toStringAsFixed(2)}',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            if (order.currentStatus == 'Delivered') ...[
                              Padding(
                                padding: const EdgeInsets.only(left: 56.0, top: 4.0),
                                child: TextButton.icon(
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(0, 0),
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    foregroundColor: theme.colorScheme.primary,
                                  ),
                                  onPressed: () {
                                    final fullProduct = shop.products.firstWhere(
                                      (p) => p.id == item.id,
                                      orElse: () => Product(
                                        id: item.id,
                                        name: item.name,
                                        category: '',
                                        description: '',
                                        price: item.price,
                                        imageUrl: item.imageUrl,
                                        rating: 5.0,
                                        reviewsCount: 0,
                                        stock: 0,
                                        reviews: [],
                                      ),
                                    );
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => ProductDetailsScreen(
                                          product: fullProduct,
                                          initialTab: 'Review',
                                          showReviewForm: true,
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.rate_review_outlined, size: 14),
                                  label: const Text(
                                    'Write a Review',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }),
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
                            '-${Provider.of<ShopProvider>(context, listen: false).currencySymbol}${order.discount.toStringAsFixed(2)}',
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
                          '${Provider.of<ShopProvider>(context, listen: false).currencySymbol}${order.total.toStringAsFixed(2)}',
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

  Widget _buildOTPView(OrderModel order) {
    return Card(
      color: const Color(0xFFE8F5E9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.green.shade300, width: 2)),
      margin: const EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.verified_user_rounded, color: Colors.green),
                SizedBox(width: 8),
                Text('Delivery Verification', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green)),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Give this 4-digit code to your delivery driver when they arrive:', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Colors.black87)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: Text(
                order.deliveryOTP ?? 'XXXX',
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 8, color: Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapView(OrderModel order) {
    if (_isLoadingMap || _destinationLocation == null) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 20),
        child: SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
      );
    }
    
    final isOutForDelivery = order.currentStatus == 'Out For Delivery';
    // Mock store location slightly offset for demo
    final storeLocation = LatLng(_destinationLocation!.latitude - 0.05, _destinationLocation!.longitude - 0.05);

    return Container(
      height: 250,
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: FlutterMap(
          options: MapOptions(
            initialCenter: _destinationLocation!,
            initialZoom: isOutForDelivery ? 11.5 : 14,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.babyshophub',
            ),
            if (isOutForDelivery)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: [storeLocation, _destinationLocation!],
                    strokeWidth: 4,
                    color: Colors.blue,
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                Marker(
                  point: _destinationLocation!,
                  width: 40,
                  height: 40,
                  child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                ),
                if (isOutForDelivery)
                  Marker(
                    point: storeLocation, // Mocking driver starting point
                    width: 40,
                    height: 40,
                    child: Container(
                      decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                      child: const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 24),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
