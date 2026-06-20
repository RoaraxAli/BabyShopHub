import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../services/shop_provider.dart';
import '../services/auth_provider.dart';
import '../services/cloudinary_service.dart';
import '../models/product.dart';
import '../models/voucher_model.dart';
import '../models/order_model.dart';
import 'home_screen.dart';
import 'auth/login_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'dart:convert';
import 'package:http/http.dart' as http;

class AdminPanel extends StatefulWidget {
  const AdminPanel({super.key});

  @override
  State<AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel> {
  int _selectedIndex = 0;

  final List<_SidebarItem> _sidebarItems = [
    _SidebarItem(icon: Icons.dashboard_rounded, label: 'Dashboard'),
    _SidebarItem(icon: Icons.inventory_2_rounded, label: 'Products'),
    _SidebarItem(icon: Icons.receipt_long_rounded, label: 'Orders'),
    _SidebarItem(icon: Icons.people_rounded, label: 'Users'),
    _SidebarItem(icon: Icons.support_agent_rounded, label: 'Support'),
    _SidebarItem(icon: Icons.settings_rounded, label: 'Settings'),
  ];

  Widget _buildBottomNavbar(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
      height: 64,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(_sidebarItems.length, (index) {
            final item = _sidebarItems[index];
            final isSelected = _selectedIndex == index;
            return InkWell(
              onTap: () => setState(() => _selectedIndex = index),
              borderRadius: BorderRadius.circular(20),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? Theme.of(context).colorScheme.primary.withOpacity(0.12) : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      item.icon,
                      size: 20,
                      color: isSelected ? Theme.of(context).colorScheme.primary : Colors.black38,
                    ),
                    if (isSelected) ...[
                      const SizedBox(width: 6),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                          fontFamily: 'Outfit',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = Provider.of<AuthProvider>(context);
    final isMobile = MediaQuery.of(context).size.width < 900;

    final List<Widget> pages = [
      const _DashboardSection(),
      const _ProductsSection(),
      const _OrdersSection(),
      const _UsersSection(),
      const _SupportSection(),
      const _SettingsSection(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9FB),
      bottomNavigationBar: isMobile ? _buildBottomNavbar(theme) : null,
      body: Row(
        children: [
          // ─── Left Sidebar (Web/Desktop only) ────────────────────────
          if (!isMobile) _buildSidebar(theme, auth),

          // ─── Main Content Area ──────────────────────────────────────
          Expanded(
            child: Column(
              children: [
                // Top Header Bar
                Container(
                  height: 64,
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFEEEEEE)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        _sidebarItems[_selectedIndex].label,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: theme.colorScheme.onSurface,
                          letterSpacing: 0.3,
                          fontFamily: 'Outfit',
                        ),
                      ),
                      const Spacer(),
                      if (isMobile) ...[
                        IconButton(
                          icon: Icon(Icons.storefront_rounded, size: 20, color: Theme.of(context).colorScheme.primary),
                          onPressed: () {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(builder: (context) => const HomeScreen()),
                            );
                          },
                          tooltip: 'View Storefront',
                        ),
                        IconButton(
                          icon: const Icon(Icons.logout_rounded, size: 20, color: Colors.black54),
                          onPressed: () async {
                            await auth.logout();
                            if (context.mounted) {
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(builder: (context) => const LoginScreen()),
                                (route) => false,
                              );
                            }
                          },
                          tooltip: 'Logout',
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.shield_rounded, size: 14, color: Theme.of(context).colorScheme.primary),
                              const SizedBox(width: 4),
                              Text('Admin', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Page Content
                Expanded(child: pages[_selectedIndex]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(ThemeData theme, AuthProvider auth) {
    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(color: Colors.black.withOpacity(0.04), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 48),
          // Logo / Branding
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Theme.of(context).colorScheme.primary, const Color(0xFFFFB347)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.child_care_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                const Text(
                  'BabyHub',
                  style: TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    letterSpacing: 0.5,
                    fontFamily: 'Outfit',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Admin Control Panel',
              style: TextStyle(color: Colors.black38, fontSize: 10, letterSpacing: 0.8, fontFamily: 'Outfit'),
            ),
          ),
          const SizedBox(height: 32),

          // Nav Items
          ...List.generate(_sidebarItems.length, (i) => _buildNavItem(i, theme)),

          const Spacer(),

          // Admin Name
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.03),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: const Icon(Icons.admin_panel_settings_rounded, size: 16, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          auth.currentUser?.displayName ?? 'Admin',
                          style: const TextStyle(color: Colors.black87, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          auth.currentUser?.email ?? '',
                          style: const TextStyle(color: Colors.black38, fontSize: 9, fontFamily: 'Outfit'),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // View as User button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (context) => const HomeScreen()),
                  );
                },
                icon: Icon(Icons.storefront_rounded, size: 14, color: Theme.of(context).colorScheme.primary),
                label: Text('View as User', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.primary, fontFamily: 'Outfit')),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ),

          // Logout
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () async {
                  await auth.logout();
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                      (route) => false,
                    );
                  }
                },
                icon: const Icon(Icons.logout_rounded, size: 14, color: Colors.black54),
                label: const Text('Logout', style: TextStyle(fontSize: 11, color: Colors.black54, fontFamily: 'Outfit')),
                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, ThemeData theme) {
    final isSelected = _selectedIndex == index;
    final item = _sidebarItems[index];

    return GestureDetector(
      onTap: () {
        setState(() => _selectedIndex = index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).colorScheme.primary.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              item.icon,
              size: 18,
              color: isSelected ? Theme.of(context).colorScheme.primary : Colors.black45,
            ),
            const SizedBox(width: 12),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Theme.of(context).colorScheme.primary : Colors.black54,
                fontFamily: 'Outfit',
              ),
            ),
            if (isSelected) ...[
              const Spacer(),
              Container(width: 4, height: 4, decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, shape: BoxShape.circle)),
            ],
          ],
        ),
      ),
    );
  }
}

class _SidebarItem {
  final IconData icon;
  final String label;
  const _SidebarItem({required this.icon, required this.label});
}

// ─────────────────────────────────────────────────────────────────────────────
// DASHBOARD SECTION
// ─────────────────────────────────────────────────────────────────────────────

class _DashboardSection extends StatefulWidget {
  const _DashboardSection();

  @override
  State<_DashboardSection> createState() => _DashboardSectionState();
}

class _DashboardSectionState extends State<_DashboardSection> {
  int _totalOrders = 0;
  int _totalUsers = 0;
  double _totalRevenue = 0;
  bool _loading = true;
  List<double> _revenueTrend = [0, 0, 0, 0, 0, 0, 0];
  List<String> _revenueLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final ordersSnap = await FirebaseFirestore.instance.collection('orders').get();
      final usersSnap = await FirebaseFirestore.instance.collection('users').get();
      double revenue = 0;
      for (var doc in ordersSnap.docs) {
        revenue += (doc.data()['total'] as num? ?? 0).toDouble();
      }

      // Group revenue by last 7 days dynamically
      final now = DateTime.now();
      final List<double> dailyRevenue = List.filled(7, 0.0);
      final List<String> labels = List.filled(7, '');
      final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final List<DateTime> days = List.generate(7, (i) {
        final date = now.subtract(Duration(days: 6 - i));
        labels[i] = weekdays[date.weekday - 1];
        return DateTime(date.year, date.month, date.day);
      });

      for (var doc in ordersSnap.docs) {
        final data = doc.data();
        final timestamp = data['createdAt'] as Timestamp?;
        if (timestamp != null) {
          final orderDate = timestamp.toDate();
          final orderDay = DateTime(orderDate.year, orderDate.month, orderDate.day);
          final index = days.indexWhere((d) => d.isAtSameMomentAs(orderDay));
          if (index >= 0) {
            dailyRevenue[index] += (data['total'] as num? ?? 0).toDouble();
          }
        }
      }

      if (mounted) {
        setState(() {
          _totalOrders = ordersSnap.docs.length;
          _totalUsers = usersSnap.docs.length;
          _totalRevenue = revenue;
          _revenueTrend = dailyRevenue;
          _revenueLabels = labels;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('[ADMIN DASHBOARD] Failed to load stats: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildStockAlertsCard(ThemeData theme, List<Product> products, int outOfStock) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Stock Alerts', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
            const SizedBox(height: 4),
            Text('$outOfStock products are out of stock', style: TextStyle(color: outOfStock > 0 ? Theme.of(context).colorScheme.primary : Colors.black54, fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'Outfit')),
            const SizedBox(height: 16),
            ...products.where((p) => p.stock <= 5).map((p) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(
                      color: p.stock == 0 ? Theme.of(context).colorScheme.primary : Colors.black26,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(p.name, style: const TextStyle(fontSize: 12, fontFamily: 'Outfit'), overflow: TextOverflow.ellipsis)),
                  Text('${p.stock} left', style: TextStyle(fontSize: 11, color: p.stock == 0 ? Theme.of(context).colorScheme.primary : Colors.black45, fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
                ],
              ),
            )),
            if (products.where((p) => p.stock <= 5).isEmpty)
              const Text('All products are well-stocked!', style: TextStyle(color: Colors.black54, fontSize: 13, fontFamily: 'Outfit')),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsCard(BuildContext context, ThemeData theme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Quick Actions', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
            const SizedBox(height: 16),
            _quickAction(context, Icons.add_box_rounded, 'Add New Product', 'Add a product to the store', Theme.of(context).colorScheme.primary,
              onTap: () {
                final adminPanel = context.findAncestorStateOfType<_AdminPanelState>();
                if (adminPanel != null) adminPanel.setState(() => adminPanel._selectedIndex = 1);
              },
            ),
            const SizedBox(height: 10),
            _quickAction(context, Icons.receipt_long_rounded, 'View All Orders', 'Review all customer orders', Theme.of(context).colorScheme.primary,
              onTap: () {
                final adminPanel = context.findAncestorStateOfType<_AdminPanelState>();
                if (adminPanel != null) adminPanel.setState(() => adminPanel._selectedIndex = 2);
              },
            ),
            const SizedBox(height: 10),
            _quickAction(context, Icons.people_rounded, 'Manage Users', 'View and manage all users', Theme.of(context).colorScheme.primary,
              onTap: () {
                final adminPanel = context.findAncestorStateOfType<_AdminPanelState>();
                if (adminPanel != null) adminPanel.setState(() => adminPanel._selectedIndex = 3);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shop = Provider.of<ShopProvider>(context);
    final products = shop.products;
    final outOfStock = products.where((p) => p.stock == 0).length;
    final size = MediaQuery.of(context).size;
    final isPhone = size.width < 750;

    if (_loading) return const Center(child: CircularProgressIndicator());

    final int crossAxisCount = isPhone ? (size.width < 450 ? 1 : 2) : 4;
    final double childAspectRatio = isPhone ? (size.width < 450 ? 3.0 : 2.4) : 2.2;

    // Calculate category counts dynamically
    final Map<String, int> catCounts = {
      'Diapers': products.where((p) => p.category == 'Diapers').length,
      'Baby Food': products.where((p) => p.category == 'Baby Food').length,
      'Clothing': products.where((p) => p.category == 'Clothing').length,
      'Toys': products.where((p) => p.category == 'Toys').length,
      'Bath': products.where((p) => p.category == 'Bath').length,
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Overview', style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface.withOpacity(0.5), fontWeight: FontWeight.w600, fontFamily: 'Outfit')),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: childAspectRatio,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildStatCard(theme, 'Total Products', '${products.length}', Icons.inventory_2_rounded, Theme.of(context).colorScheme.primary),
              _buildStatCard(theme, 'Total Orders', '$_totalOrders', Icons.receipt_long_rounded, Theme.of(context).colorScheme.primary),
              _buildStatCard(theme, 'Total Users', '$_totalUsers', Icons.people_rounded, Theme.of(context).colorScheme.primary),
              _buildStatCard(theme, 'Total Revenue', '\$${_totalRevenue.toStringAsFixed(2)}', Icons.attach_money_rounded, Theme.of(context).colorScheme.primary),
            ],
          ),
          const SizedBox(height: 24),
          
          // Analytics Charts
          if (isPhone) ...[
            _RevenueTrendChart(revenueData: _revenueTrend, labels: _revenueLabels),
            const SizedBox(height: 16),
            _CategoryDistributionChart(categoryCounts: catCounts),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: _RevenueTrendChart(revenueData: _revenueTrend, labels: _revenueLabels),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _CategoryDistributionChart(categoryCounts: catCounts),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),

          if (isPhone) ...[
            _buildStockAlertsCard(theme, products, outOfStock),
            const SizedBox(height: 16),
            _buildQuickActionsCard(context, theme),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildStockAlertsCard(theme, products, outOfStock)),
                const SizedBox(width: 16),
                Expanded(child: _buildQuickActionsCard(context, theme)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _quickAction(BuildContext context, IconData icon, String title, String subtitle, Color color, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF9F9FB),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
                  Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.black38, fontFamily: 'Outfit')),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Theme.of(context).colorScheme.primary, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(ThemeData theme, String label, String value, IconData icon, Color color) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: const Color(0xFFF9F9FB),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: theme.colorScheme.onSurface,
                        fontFamily: 'Outfit',
                      ),
                    ),
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Outfit',
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PRODUCTS SECTION
// ─────────────────────────────────────────────────────────────────────────────

class _ProductsSection extends StatelessWidget {
  const _ProductsSection();

  void _showProductForm(BuildContext context, {Product? product}) {
    final nameCtrl = TextEditingController(text: product?.name ?? '');
    final priceCtrl = TextEditingController(text: product != null ? product.price.toString() : '');
    final stockCtrl = TextEditingController(text: product != null ? product.stock.toString() : '');
    final descCtrl = TextEditingController(text: product?.description ?? '');
    final imgCtrl = TextEditingController(text: product?.imageUrl ?? '');
    
    final shop = Provider.of<ShopProvider>(context, listen: false);
    final categories = shop.categories.map((c) => c.name).toList();
    if (categories.isEmpty) categories.add('General');
    if (product != null && !categories.contains(product.category)) {
      categories.add(product.category);
    }
    String selectedCategory = product?.category ?? categories.first;
    
    final formKey = GlobalKey<FormState>();
    final isNew = product == null;
    bool isUploading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final theme = Theme.of(ctx);
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(isNew ? 'Add New Product' : 'Edit Product', style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
            content: SizedBox(
              width: 480,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(labelText: 'Product Name', prefixIcon: Icon(Icons.label_outline)),
                        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                        style: const TextStyle(fontSize: 14, fontFamily: 'Outfit'),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: priceCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                              decoration: const InputDecoration(labelText: 'Price (\$)', prefixIcon: Icon(Icons.attach_money)),
                              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                              style: const TextStyle(fontSize: 14, fontFamily: 'Outfit'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: stockCtrl,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              decoration: const InputDecoration(labelText: 'Stock Qty', prefixIcon: Icon(Icons.inventory_2_outlined)),
                              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                              style: const TextStyle(fontSize: 14, fontFamily: 'Outfit'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedCategory,
                        items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontFamily: 'Outfit')))).toList(),
                        onChanged: (v) => setDialogState(() => selectedCategory = v ?? selectedCategory),
                        decoration: const InputDecoration(labelText: 'Category', prefixIcon: Icon(Icons.category_outlined)),
                        style: const TextStyle(fontSize: 14, fontFamily: 'Outfit'),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: imgCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Image URL',
                                prefixIcon: Icon(Icons.image_outlined),
                                hintText: 'Paste link or upload',
                              ),
                              style: const TextStyle(fontSize: 14, fontFamily: 'Outfit'),
                              onChanged: (val) {
                                setDialogState(() {});
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          isUploading
                              ? const SizedBox(
                                  width: 44,
                                  height: 44,
                                  child: Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                )
                              : SizedBox(
                                  height: 52,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    ),
                                    onPressed: () async {
                                      final ImagePicker picker = ImagePicker();
                                      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                                      if (image != null) {
                                        setDialogState(() {
                                          isUploading = true;
                                        });
                                        final CloudinaryService cloudinary = CloudinaryService();
                                        await cloudinary.init();
                                        final String? url = await cloudinary.uploadImage(image);
                                        setDialogState(() {
                                          isUploading = false;
                                          if (url != null) {
                                            imgCtrl.text = url;
                                          }
                                        });
                                      }
                                    },
                                    icon: const Icon(Icons.cloud_upload_rounded, size: 18),
                                    label: const Text('Upload', style: TextStyle(fontSize: 12, fontFamily: 'Outfit')),
                                  ),
                                ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (imgCtrl.text.trim().isNotEmpty) ...[
                        Container(
                          height: 130,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(
                              imgCtrl.text.trim(),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Center(
                                child: Text('No preview available (Check Image URL)', style: TextStyle(fontSize: 11, color: Colors.grey, fontFamily: 'Outfit')),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextFormField(
                        controller: descCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(labelText: 'Description', prefixIcon: Icon(Icons.description_outlined)),
                        style: const TextStyle(fontSize: 14, fontFamily: 'Outfit'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel', style: TextStyle(fontFamily: 'Outfit'))),
              ElevatedButton.icon(
                icon: Icon(isNew ? Icons.add : Icons.save_rounded, size: 16),
                label: Text(isNew ? 'Add Product' : 'Save Changes', style: const TextStyle(fontFamily: 'Outfit')),
                style: ElevatedButton.styleFrom(elevation: 0),
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  final shop = Provider.of<ShopProvider>(context, listen: false);
                  final data = {
                    'name': nameCtrl.text.trim(),
                    'price': double.tryParse(priceCtrl.text.trim()) ?? 0.0,
                    'stock': int.tryParse(stockCtrl.text.trim()) ?? 0,
                    'category': selectedCategory,
                    'description': descCtrl.text.trim(),
                    'imageUrl': imgCtrl.text.trim(),
                    'rating': product?.rating ?? 5.0,
                    'reviewsCount': product?.reviewsCount ?? 0,
                  };
                  try {
                    if (isNew) {
                      await FirebaseFirestore.instance.collection('products').add(data);
                    } else {
                      await FirebaseFirestore.instance.collection('products').doc(product.id).update(data);
                      shop.updateProductStock(product.id, int.tryParse(stockCtrl.text.trim()) ?? 0);
                    }
                    await shop.refreshProducts();
                  } catch (_) {}
                  if (ctx.mounted) Navigator.of(ctx).pop();
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _showCategoryManager(BuildContext context) {
    final nameCtrl = TextEditingController();
    final imgCtrl = TextEditingController();
    bool isUploading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final shop = Provider.of<ShopProvider>(ctx);
          
          return AlertDialog(
            title: const Text('Manage Categories', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
            content: SizedBox(
              width: 400,
              height: 400,
              child: Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      itemCount: shop.categories.length,
                      itemBuilder: (context, i) {
                        final cat = shop.categories[i];
                        return ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: cat.imageUrl.startsWith('http')
                                ? Image.network(cat.imageUrl, width: 40, height: 40, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.image))
                                : const Icon(Icons.image),
                          ),
                          title: Text(cat.name, style: const TextStyle(fontFamily: 'Outfit')),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => shop.deleteCategory(cat.id),
                          ),
                        );
                      },
                    ),
                  ),
                  const Divider(),
                  const Text('Add New Category', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Category Name', isDense: true),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: imgCtrl,
                          decoration: const InputDecoration(labelText: 'Image URL', isDense: true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      isUploading ? const CircularProgressIndicator() : IconButton(
                        icon: const Icon(Icons.upload_file),
                        onPressed: () async {
                          final ImagePicker picker = ImagePicker();
                          final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                          if (image != null) {
                            setDialogState(() => isUploading = true);
                            final CloudinaryService cloudinary = CloudinaryService();
                            await cloudinary.init();
                            final String? url = await cloudinary.uploadImage(image);
                            setDialogState(() {
                              isUploading = false;
                              if (url != null) imgCtrl.text = url;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {
                      if (nameCtrl.text.isNotEmpty && imgCtrl.text.isNotEmpty) {
                        shop.addCategory(nameCtrl.text.trim(), imgCtrl.text.trim());
                        nameCtrl.clear();
                        imgCtrl.clear();
                      }
                    },
                    child: const Text('Add Category'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shop = Provider.of<ShopProvider>(context);
    final products = shop.products;
    final size = MediaQuery.of(context).size;
    final isPhone = size.width < 750;

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('${products.length} products in store', style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withOpacity(0.5), fontFamily: 'Outfit')),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _showCategoryManager(context),
                icon: const Icon(Icons.category_rounded, size: 16),
                label: const Text('Categories', style: TextStyle(fontFamily: 'Outfit')),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Theme.of(context).colorScheme.primary, elevation: 0, side: BorderSide(color: Theme.of(context).colorScheme.primary)),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => _showProductForm(context),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Add Product', style: TextStyle(fontFamily: 'Outfit')),
                style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Colors.white, elevation: 0),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: isPhone
                ? ListView.builder(
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      final p = products[index];
                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(p.imageUrl, width: 64, height: 64, fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 64, height: 64,
                                    color: theme.colorScheme.onSurface.withOpacity(0.05),
                                    child: Icon(Icons.child_care_rounded, size: 28, color: Theme.of(context).colorScheme.primary),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(p.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Outfit'), maxLines: 2, overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(p.category, style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
                                        ),
                                        const SizedBox(width: 8),
                                        Text('\$${p.price.toStringAsFixed(2)}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, fontFamily: 'Outfit', color: Theme.of(context).colorScheme.primary)),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Container(
                                          width: 7, height: 7,
                                          decoration: BoxDecoration(
                                            color: p.stock == 0 ? Theme.of(context).colorScheme.primary : Colors.black26,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(p.stock == 0 ? 'Out of stock' : '${p.stock} in stock',
                                          style: TextStyle(fontSize: 11, color: p.stock == 0 ? Theme.of(context).colorScheme.primary : Colors.black54, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_rounded, size: 20),
                                    color: Theme.of(context).colorScheme.primary,
                                    onPressed: () => _showProductForm(context, product: p),
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.all(8),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_rounded, size: 20),
                                    color: Colors.black45,
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.all(8),
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                          title: const Text('Delete Product', style: TextStyle(fontFamily: 'Outfit')),
                                          content: Text('Are you sure you want to delete "${p.name}"?', style: const TextStyle(fontFamily: 'Outfit')),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel', style: TextStyle(fontFamily: 'Outfit'))),
                                            ElevatedButton(
                                              onPressed: () async {
                                                try {
                                                  await FirebaseFirestore.instance.collection('products').doc(p.id).delete();
                                                  await shop.refreshProducts();
                                                } catch (e) {
                                                  debugPrint('[ADMIN PRODUCTS] Delete failed: $e');
                                                }
                                                if (ctx.mounted) Navigator.of(ctx).pop();
                                              },
                                              style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Colors.white, elevation: 0),
                                              child: const Text('Delete', style: TextStyle(fontFamily: 'Outfit')),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  )
                : Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9F9FB),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                          ),
                          child: const Row(
                            children: [
                              SizedBox(width: 56),
                              Expanded(flex: 3, child: Text('Product Name', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Outfit'))),
                              Expanded(child: Text('Category', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Outfit'))),
                              Expanded(child: Text('Price', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Outfit'))),
                              Expanded(child: Text('Stock', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Outfit'))),
                              SizedBox(width: 80, child: Text('Actions', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Outfit'))),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView.separated(
                            itemCount: products.length,
                            separatorBuilder: (_, __) => Divider(height: 1, color: Colors.black.withOpacity(0.04)),
                            itemBuilder: (context, index) {
                              final p = products[index];
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(p.imageUrl, width: 40, height: 40, fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(width: 40, height: 40, color: Colors.grey.shade200,
                                          child: const Icon(Icons.child_care_rounded, size: 20)),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(flex: 3, child: Text(p.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'Outfit'), overflow: TextOverflow.ellipsis)),
                                    Expanded(child: Text(p.category, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withOpacity(0.6), fontFamily: 'Outfit'))),
                                    Expanded(child: Text('\$${p.price.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'Outfit'))),
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 8, height: 8,
                                            decoration: BoxDecoration(
                                              color: p.stock == 0 ? Theme.of(context).colorScheme.primary : Colors.black26,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text('${p.stock}', style: TextStyle(fontSize: 13, color: p.stock == 0 ? Theme.of(context).colorScheme.primary : theme.colorScheme.onSurface, fontWeight: FontWeight.w600, fontFamily: 'Outfit')),
                                        ],
                                      ),
                                    ),
                                    SizedBox(
                                      width: 80,
                                      child: Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit_rounded, size: 18),
                                            color: Theme.of(context).colorScheme.primary,
                                            tooltip: 'Edit',
                                            padding: EdgeInsets.zero,
                                            onPressed: () => _showProductForm(context, product: p),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete_rounded, size: 18),
                                            color: Colors.black45,
                                            tooltip: 'Delete',
                                            padding: EdgeInsets.zero,
                                            onPressed: () {
                                              showDialog(
                                                context: context,
                                                builder: (ctx) => AlertDialog(
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                                  title: const Text('Delete Product', style: TextStyle(fontFamily: 'Outfit')),
                                                  content: Text('Are you sure you want to delete "${p.name}"?', style: const TextStyle(fontFamily: 'Outfit')),
                                                  actions: [
                                                    TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel', style: TextStyle(fontFamily: 'Outfit'))),
                                                    ElevatedButton(
                                                      onPressed: () async {
                                                        try {
                                                          await FirebaseFirestore.instance.collection('products').doc(p.id).delete();
                                                          await shop.refreshProducts();
                                                        } catch (e) {
                                                          debugPrint('[ADMIN PRODUCTS] Delete failed: $e');
                                                        }
                                                        if (ctx.mounted) Navigator.of(ctx).pop();
                                                      },
                                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white, elevation: 0),
                                                      child: const Text('Delete', style: TextStyle(fontFamily: 'Outfit')),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ORDERS SECTION
// ─────────────────────────────────────────────────────────────────────────────

class _OrdersSection extends StatefulWidget {
  const _OrdersSection();

  @override
  State<_OrdersSection> createState() => _OrdersSectionState();
}

class _OrdersSectionState extends State<_OrdersSection> {
  List<Map<String, dynamic>> _orders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('orders')
          .get();
      final docs = snap.docs.map((d) {
        final data = d.data();
        data['id'] = d.id;
        return data;
      }).toList();

      // Sort by createdAt descending in Dart (avoids needing a Firestore index)
      docs.sort((a, b) {
        final aTs = a['createdAt'];
        final bTs = b['createdAt'];
        if (aTs == null && bTs == null) return 0;
        if (aTs == null) return 1;
        if (bTs == null) return -1;
        final aDate = (aTs as Timestamp).toDate();
        final bDate = (bTs as Timestamp).toDate();
        return bDate.compareTo(aDate);
      });

      if (mounted) {
        setState(() {
          _orders = docs;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('[ADMIN ORDERS] Failed to load orders: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showVoucherManager(BuildContext context) {
    final codeCtrl = TextEditingController();
    final valCtrl = TextEditingController();
    final minCtrl = TextEditingController();
    String selectedType = 'percentage';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final shop = Provider.of<ShopProvider>(ctx);
          
          return AlertDialog(
            title: const Text('Manage Vouchers', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
            content: SizedBox(
              width: 450,
              height: 480,
              child: Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      itemCount: shop.vouchers.length,
                      itemBuilder: (context, i) {
                        final v = shop.vouchers[i];
                        final discountText = v.type == 'percentage'
                            ? '${(v.value * 100).toStringAsFixed(0)}% Off'
                            : '\$${v.value.toStringAsFixed(2)} Off';
                        final minText = v.minPurchase > 0
                            ? 'Min: \$${v.minPurchase.toStringAsFixed(0)}'
                            : 'No Min';
                        
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            child: const Icon(Icons.local_offer_rounded, color: Colors.white, size: 18),
                          ),
                          title: Text(v.code, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
                          subtitle: Text('$discountText | $minText', style: const TextStyle(fontFamily: 'Outfit', fontSize: 12)),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => shop.deleteVoucher(v.id),
                          ),
                        );
                      },
                    ),
                  ),
                  const Divider(),
                  const Text('Create New Voucher', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: codeCtrl,
                          decoration: const InputDecoration(labelText: 'Voucher Code (e.g. SAVE15)', isDense: true),
                          style: const TextStyle(fontSize: 13, fontFamily: 'Outfit'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      DropdownButton<String>(
                        value: selectedType,
                        items: const [
                          DropdownMenuItem(value: 'percentage', child: Text('Percentage (%)')),
                          DropdownMenuItem(value: 'flat', child: Text('Flat Amount (\$)')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => selectedType = val);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: valCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: selectedType == 'percentage' ? 'Discount (e.g. 0.15 for 15%)' : 'Discount (\$)',
                            isDense: true,
                          ),
                          style: const TextStyle(fontSize: 13, fontFamily: 'Outfit'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: minCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Min Purchase (\$)', isDense: true),
                          style: const TextStyle(fontSize: 13, fontFamily: 'Outfit'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {
                      final code = codeCtrl.text.trim();
                      final val = double.tryParse(valCtrl.text.trim()) ?? 0.0;
                      final min = double.tryParse(minCtrl.text.trim()) ?? 0.0;
                      
                      if (code.isNotEmpty && val > 0) {
                        shop.addVoucher(code, selectedType, val, min);
                        codeCtrl.clear();
                        valCtrl.clear();
                        minCtrl.clear();
                      }
                    },
                    child: const Text('Add Voucher'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
            ],
          );
        },
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Delivered':
        return Theme.of(context).colorScheme.primary;
      case 'Cancelled':
        return Colors.black38;
      default:
        return Colors.black87;
    }
  }

  void _showOrderManageDialog(BuildContext context, Map<String, dynamic> order) {
    final orderIdFull = order['id'] as String? ?? '';
    final orderIdShort = orderIdFull.length > 8 ? orderIdFull.substring(0, 8).toUpperCase() : orderIdFull.toUpperCase();
    
    final rawHistory = order['statusHistory'] as List? ?? [];
    String currentStatus = 'Pending';
    if (rawHistory.isNotEmpty) {
      currentStatus = rawHistory.last['status'] ?? 'Pending';
    } else if (order['status'] != null) {
      currentStatus = order['status'];
    }

    String selectedStatus = currentStatus;
    final notesController = TextEditingController();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Manage Order #$orderIdShort'),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Customer: ${order['email'] ?? 'N/A'}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('Address: ${order['address'] ?? 'N/A'}'),
                    const SizedBox(height: 8),
                    if (order['promoCode'] != null)
                      Text(
                        'Voucher: ${order['promoCode']} (-\$${(order['discount'] ?? 0.0).toStringAsFixed(2)})',
                        style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                      )
                    else
                      const Text('Voucher: None'),
                    const SizedBox(height: 16),
                    const Text('Change Status:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: OrderModel.allStatuses.contains(selectedStatus) ? selectedStatus : 'Pending',
                      items: OrderModel.allStatuses.map((s) {
                        return DropdownMenuItem<String>(
                          value: s,
                          child: Text(s),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            selectedStatus = val;
                          });
                        }
                      },
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Status Notes / Update Message:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: notesController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        hintText: 'e.g. Package has been dispatched via UPS.',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Status Timeline:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...rawHistory.map((h) {
                      final timeVal = h['timestamp'];
                      final dt = timeVal is Timestamp
                          ? timeVal.toDate()
                          : (timeVal is String ? DateTime.tryParse(timeVal) ?? DateTime.now() : DateTime.now());
                      
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6.0),
                        child: Text(
                          '• [${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}] ${h['status']}: ${h['note'] ?? ''}',
                          style: const TextStyle(fontSize: 11),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
                ElevatedButton(
                  onPressed: isSaving ? null : () async {
                    setDialogState(() {
                      isSaving = true;
                    });
                    
                    try {
                      final newEntry = {
                        'status': selectedStatus,
                        'timestamp': Timestamp.now(),
                        'note': notesController.text.trim().isNotEmpty 
                            ? notesController.text.trim()
                            : 'Status updated by admin',
                      };

                      await FirebaseFirestore.instance.collection('orders').doc(orderIdFull).update({
                        'statusHistory': FieldValue.arrayUnion([newEntry]),
                      });

                      final userId = order['userId'] as String? ?? '';
                      if (userId.isNotEmpty) {
                        final notifRef = FirebaseFirestore.instance
                            .collection('users')
                            .doc(userId)
                            .collection('notifications')
                            .doc();
                        
                        await notifRef.set({
                          'id': notifRef.id,
                          'title': 'Order Update: $selectedStatus',
                          'body': 'Your order #$orderIdShort is now $selectedStatus. ${newEntry['note']}',
                          'type': 'order',
                          'read': false,
                          'createdAt': FieldValue.serverTimestamp(),
                        });
                      }

                      await _loadOrders();

                      if (context.mounted) {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Order #$orderIdShort status updated to $selectedStatus')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error updating status: $e')),
                        );
                      }
                    } finally {
                      setDialogState(() {
                        isSaving = false;
                      });
                    }
                  },
                  child: const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isPhone = size.width < 750;

    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined, size: 64, color: theme.colorScheme.onSurface.withOpacity(0.2)),
            const SizedBox(height: 16),
            Text('No orders yet', style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.4), fontSize: 16, fontFamily: 'Outfit')),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('${_orders.length} total orders', style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withOpacity(0.5), fontFamily: 'Outfit')),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _showVoucherManager(context),
                icon: const Icon(Icons.local_offer_rounded, size: 16),
                label: const Text('Manage Vouchers', style: TextStyle(fontFamily: 'Outfit')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Theme.of(context).colorScheme.primary,
                  elevation: 0,
                  side: BorderSide(color: Theme.of(context).colorScheme.primary),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(onPressed: _loadOrders, icon: const Icon(Icons.refresh_rounded), tooltip: 'Refresh'),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: isPhone
                ? ListView.builder(
                    itemCount: _orders.length,
                    itemBuilder: (context, index) {
                      final order = _orders[index];
                      final orderId = (order['id'] as String? ?? '').substring(0, 8).toUpperCase();
                      final email = order['email'] as String? ?? 'N/A';
                      final address = order['address'] as String? ?? 'N/A';
                      final total = (order['total'] as num? ?? 0).toDouble();
                      final items = order['items'] as List? ?? [];
                      
                      final rawHistory = order['statusHistory'] as List? ?? [];
                      String currentStatus = 'Pending';
                      if (rawHistory.isNotEmpty) {
                        currentStatus = rawHistory.last['status'] ?? 'Pending';
                      } else if (order['status'] != null) {
                        currentStatus = order['status'];
                      }

                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),

                        ),
                        child: InkWell(
                          onTap: () => _showOrderManageDialog(context, order),
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.04),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text('#$orderId', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87, fontFamily: 'Outfit')),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: _statusColor(currentStatus).withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        currentStatus,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: _statusColor(currentStatus),
                                          fontFamily: 'Outfit',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                Row(
                                  children: [
                                    Icon(Icons.mail_outline_rounded, size: 16, color: theme.colorScheme.onSurface.withOpacity(0.4)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        email,
                                        style: const TextStyle(fontSize: 13, fontFamily: 'Outfit'),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.location_on_outlined, size: 16, color: theme.colorScheme.onSurface.withOpacity(0.4)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        address,
                                        style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withOpacity(0.6), fontFamily: 'Outfit'),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                const Divider(height: 1, thickness: 0.5),
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${items.length} item${items.length != 1 ? 's' : ''}',
                                          style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withOpacity(0.5), fontFamily: 'Outfit', fontWeight: FontWeight.w500),
                                        ),
                                        if (order['promoCode'] != null)
                                          Text(
                                            'Voucher: ${order['promoCode']}',
                                            style: const TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                                          ),
                                      ],
                                    ),
                                    Text(
                                      '\$${total.toStringAsFixed(2)}',
                                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.primary, fontFamily: 'Outfit'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  )
                : Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9F9FB),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                          ),
                          child: const Row(
                            children: [
                              Expanded(flex: 2, child: Text('Order ID', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Outfit'))),
                              Expanded(flex: 2, child: Text('Customer Email', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Outfit'))),
                              Expanded(flex: 3, child: Text('Shipping Address', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Outfit'))),
                              Expanded(child: Text('Total', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Outfit'))),
                              Expanded(child: Text('Items', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Outfit'))),
                              Expanded(child: Text('Status', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Outfit'))),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView.separated(
                            itemCount: _orders.length,
                            separatorBuilder: (_, __) => Divider(height: 1, color: Colors.black.withOpacity(0.04)),
                            itemBuilder: (context, index) {
                              final order = _orders[index];
                              final orderId = (order['id'] as String? ?? '').substring(0, 8).toUpperCase();
                              final email = order['email'] as String? ?? 'N/A';
                              final address = order['address'] as String? ?? 'N/A';
                              final total = (order['total'] as num? ?? 0).toDouble();
                              final items = order['items'] as List? ?? [];
                              
                              final rawHistory = order['statusHistory'] as List? ?? [];
                              String currentStatus = 'Pending';
                              if (rawHistory.isNotEmpty) {
                                currentStatus = rawHistory.last['status'] ?? 'Pending';
                              } else if (order['status'] != null) {
                                currentStatus = order['status'];
                              }

                              return InkWell(
                                onTap: () => _showOrderManageDialog(context, order),
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 2,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(0.04),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text('#$orderId', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87, fontFamily: 'Outfit')),
                                        ),
                                      ),
                                      Expanded(flex: 2, child: Text(email, style: const TextStyle(fontSize: 12, fontFamily: 'Outfit'), overflow: TextOverflow.ellipsis)),
                                      Expanded(flex: 3, child: Text(address, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withOpacity(0.6), fontFamily: 'Outfit'), overflow: TextOverflow.ellipsis)),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text('\$${total.toStringAsFixed(2)}',
                                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary, fontFamily: 'Outfit')),
                                            if (order['promoCode'] != null)
                                              Text(
                                                'Voucher: ${order['promoCode']}',
                                                style: const TextStyle(fontSize: 9, color: Colors.green, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        child: Text('${items.length} item${items.length != 1 ? 's' : ''}',
                                          style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withOpacity(0.6), fontFamily: 'Outfit')),
                                      ),
                                      Expanded(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: _statusColor(currentStatus).withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            currentStatus,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: _statusColor(currentStatus),
                                              fontFamily: 'Outfit',
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// USERS SECTION
// ─────────────────────────────────────────────────────────────────────────────

class _UsersSection extends StatefulWidget {
  const _UsersSection();

  @override
  State<_UsersSection> createState() => _UsersSectionState();
}

class _UsersSectionState extends State<_UsersSection> {
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('users').get();
      setState(() {
        _users = snap.docs.map((d) {
          final data = d.data();
          data['id'] = d.id;
          return data;
        }).toList();
        _loading = false;
      });
    } catch (e) {
      debugPrint('[ADMIN USERS] Failed to load users: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showUserForm(BuildContext context, {Map<String, dynamic>? user}) {
    final nameCtrl = TextEditingController(text: user?['displayName'] ?? '');
    final emailCtrl = TextEditingController(text: user?['email'] ?? '');
    final passwordCtrl = TextEditingController();
    String selectedRole = user?['role'] ?? 'user';
    final formKey = GlobalKey<FormState>();
    final isNew = user == null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(isNew ? 'Add New User' : 'Edit User', style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
            content: SizedBox(
              width: 400,
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Display Name', prefixIcon: Icon(Icons.person_outline_rounded)),
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                      style: const TextStyle(fontSize: 14, fontFamily: 'Outfit'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: emailCtrl,
                      decoration: const InputDecoration(labelText: 'Email Address', prefixIcon: Icon(Icons.mail_outline_rounded)),
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                      style: const TextStyle(fontSize: 14, fontFamily: 'Outfit'),
                      enabled: isNew,
                    ),
                    if (isNew) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: passwordCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline_rounded)),
                        validator: (v) => v == null || v.length < 6 ? 'Min 6 chars' : null,
                        style: const TextStyle(fontSize: 14, fontFamily: 'Outfit'),
                      ),
                    ],
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedRole,
                      items: const [
                        DropdownMenuItem(value: 'user', child: Text('User', style: TextStyle(fontFamily: 'Outfit'))),
                        DropdownMenuItem(value: 'admin', child: Text('Admin', style: TextStyle(fontFamily: 'Outfit'))),
                        DropdownMenuItem(value: 'delivery', child: Text('Delivery Person', style: TextStyle(fontFamily: 'Outfit'))),
                      ],
                      onChanged: (v) => setDialogState(() => selectedRole = v ?? selectedRole),
                      decoration: const InputDecoration(labelText: 'Role', prefixIcon: Icon(Icons.shield_outlined)),
                      style: const TextStyle(fontSize: 14, fontFamily: 'Outfit'),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel', style: TextStyle(fontFamily: 'Outfit'))),
              ElevatedButton.icon(
                icon: Icon(isNew ? Icons.person_add_rounded : Icons.save_rounded, size: 16),
                label: Text(isNew ? 'Add User' : 'Save Changes', style: const TextStyle(fontFamily: 'Outfit')),
                style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Colors.white, elevation: 0),
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  
                  final data = {
                    'displayName': nameCtrl.text.trim(),
                    'email': emailCtrl.text.trim(),
                    'role': selectedRole,
                    if (isNew) 'createdAt': FieldValue.serverTimestamp(),
                    if (isNew) 'avatarIndex': 0,
                    if (isNew) 'isTotpEnabled': false,
                  };

                  try {
                    if (isNew) {
                      // Use Firebase Auth REST API to avoid IndexDB Web lock errors and prevent logging out admin
                      final apiKey = Firebase.app().options.apiKey;
                      final url = Uri.parse('https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$apiKey');
                      final response = await http.post(
                        url,
                        headers: {'Content-Type': 'application/json'},
                        body: json.encode({
                          'email': emailCtrl.text.trim(),
                          'password': passwordCtrl.text,
                          'returnSecureToken': false,
                        }),
                      );
                      
                      if (response.statusCode == 200) {
                        final respData = json.decode(response.body);
                        data['uid'] = respData['localId'];
                        await FirebaseFirestore.instance.collection('users').doc(respData['localId']).set(data);
                      } else {
                        throw Exception('REST Auth error: ${response.body}');
                      }
                    } else {
                      await FirebaseFirestore.instance.collection('users').doc(user['id']).update({
                        'displayName': nameCtrl.text.trim(),
                        'role': selectedRole,
                      });
                    }
                    _loadUsers();
                  } catch (e) {
                    debugPrint('[ADMIN USERS] Save failed: $e');
                    String errorMessage = 'Failed to save user.';
                    if (e.toString().contains('EMAIL_EXISTS')) {
                      errorMessage = 'This email is already registered in Firebase Authentication.';
                    } else if (e.toString().contains('REST Auth error')) {
                      errorMessage = 'Authentication error. Please check details and try again.';
                    }
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(errorMessage, style: const TextStyle(fontFamily: 'Outfit')), backgroundColor: Colors.red));
                    }
                    return; // Don't close the dialog if there's an error
                  }
                  if (ctx.mounted) Navigator.of(ctx).pop();
                },
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUid = Provider.of<AuthProvider>(context, listen: false).currentUser?.uid;
    final size = MediaQuery.of(context).size;
    final isPhone = size.width < 750;

    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_users.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline_rounded, size: 64, color: theme.colorScheme.onSurface.withOpacity(0.2)),
            const SizedBox(height: 16),
            Text('No users found', style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.4), fontSize: 16, fontFamily: 'Outfit')),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('${_users.length} registered users', style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withOpacity(0.5), fontFamily: 'Outfit')),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _showUserForm(context),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Add User', style: TextStyle(fontFamily: 'Outfit')),
                style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Colors.white, elevation: 0),
              ),
              const SizedBox(width: 12),
              IconButton(onPressed: _loadUsers, icon: const Icon(Icons.refresh_rounded), tooltip: 'Refresh'),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: isPhone
                ? ListView.builder(
                    itemCount: _users.length,
                    itemBuilder: (context, index) {
                      final user = _users[index];
                      final uid = user['id'] as String? ?? '';
                      final name = user['displayName'] as String? ?? 'Unknown';
                      final email = user['email'] as String? ?? '';
                      final role = user['role'] as String? ?? 'user';
                      final isCurrentUser = uid == currentUid;
                      final isAdmin = role == 'admin';
                      final isDelivery = role == 'delivery';

                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),

                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: isAdmin ? Theme.of(context).colorScheme.primary.withOpacity(0.2) : (isDelivery ? Colors.blue.withOpacity(0.2) : Colors.black.withOpacity(0.05)),
                                child: Icon(
                                  isAdmin ? Icons.admin_panel_settings_rounded : (isDelivery ? Icons.local_shipping_rounded : Icons.person_rounded),
                                  size: 22,
                                  color: isAdmin ? Theme.of(context).colorScheme.primary : (isDelivery ? Colors.blue : Colors.black54),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isCurrentUser ? '$name (You)' : name,
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      email,
                                      style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withOpacity(0.6), fontFamily: 'Outfit'),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: isAdmin ? Theme.of(context).colorScheme.primary.withOpacity(0.12) : Colors.black.withOpacity(0.04),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            isAdmin ? 'Admin' : 'User',
                                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isAdmin ? Theme.of(context).colorScheme.primary : Colors.black54, fontFamily: 'Outfit'),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    if (!isCurrentUser)
                                      Row(
                                        children: [
                                          _userActionBtn(
                                            icon: Icons.edit_rounded,
                                            color: Theme.of(context).colorScheme.primary,
                                            tooltip: 'Edit User',
                                            onTap: () => _showUserForm(context, user: user),
                                          ),
                                          const SizedBox(width: 4),
                                          _userActionBtn(
                                            icon: Icons.delete_rounded,
                                            color: Colors.black38,
                                            tooltip: 'Delete User',
                                            onTap: () => _deleteUser(context, uid, name),
                                          ),
                                          const SizedBox(width: 4),
                                          _userActionBtn(
                                            icon: isAdmin ? Icons.person_remove_rounded : Icons.shield_rounded,
                                            color: isAdmin ? Colors.black38 : Theme.of(context).colorScheme.primary,
                                            tooltip: isAdmin ? 'Revoke Admin' : 'Make Admin',
                                            onTap: () => _toggleUserRole(uid, role),
                                          ),
                                        ],
                                      )
                                    else
                                      Text(
                                        'Cannot edit self',
                                        style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurface.withOpacity(0.3), fontFamily: 'Outfit'),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  )
                : Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9F9FB),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                          ),
                          child: const Row(
                            children: [
                              SizedBox(width: 44),
                              Expanded(flex: 2, child: Text('Display Name', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Outfit'))),
                              Expanded(flex: 3, child: Text('Email', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Outfit'))),
                              Expanded(child: Text('Role', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Outfit'))),
                              SizedBox(width: 180, child: Text('Actions', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Outfit'))),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView.separated(
                            itemCount: _users.length,
                            separatorBuilder: (_, __) => Divider(height: 1, color: Colors.black.withOpacity(0.04)),
                            itemBuilder: (context, index) {
                              final user = _users[index];
                              final uid = user['id'] as String? ?? '';
                              final name = user['displayName'] as String? ?? 'Unknown';
                              final email = user['email'] as String? ?? '';
                              final role = user['role'] as String? ?? 'user';
                              final isCurrentUser = uid == currentUid;
                              final isAdmin = role == 'admin';

                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: isAdmin ? Theme.of(context).colorScheme.primary.withOpacity(0.2) : Colors.black.withOpacity(0.05),
                                      child: Icon(
                                        isAdmin ? Icons.admin_panel_settings_rounded : Icons.person_rounded,
                                        size: 16,
                                        color: isAdmin ? Theme.of(context).colorScheme.primary : Colors.black54,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        isCurrentUser ? '$name (You)' : name,
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'Outfit'),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Expanded(flex: 3, child: Text(email, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withOpacity(0.6), fontFamily: 'Outfit'), overflow: TextOverflow.ellipsis)),
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: isAdmin ? Theme.of(context).colorScheme.primary.withOpacity(0.12) : Colors.black.withOpacity(0.04),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          isAdmin ? 'Admin' : 'User',
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isAdmin ? Theme.of(context).colorScheme.primary : Colors.black54, fontFamily: 'Outfit'),
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 180,
                                      child: isCurrentUser
                                          ? Text('Cannot edit self', style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurface.withOpacity(0.3), fontFamily: 'Outfit'))
                                          : Row(
                                              children: [
                                                _userActionBtn(
                                                  icon: Icons.edit_rounded,
                                                  color: Theme.of(context).colorScheme.primary,
                                                  tooltip: 'Edit',
                                                  onTap: () => _showUserForm(context, user: user),
                                                ),
                                                const SizedBox(width: 2),
                                                _userActionBtn(
                                                  icon: Icons.delete_rounded,
                                                  color: Colors.black38,
                                                  tooltip: 'Delete',
                                                  onTap: () => _deleteUser(context, uid, name),
                                                ),
                                                const SizedBox(width: 2),
                                                _userActionBtn(
                                                  icon: isAdmin ? Icons.person_remove_rounded : Icons.shield_rounded,
                                                  color: isAdmin ? Colors.black38 : Theme.of(context).colorScheme.primary,
                                                  tooltip: isAdmin ? 'Revoke Admin' : 'Make Admin',
                                                  onTap: () => _toggleUserRole(uid, role),
                                                ),
                                              ],
                                            ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleUserRole(String uid, String currentRole) async {
    String newRole = 'user';
    if (currentRole == 'user') newRole = 'admin';
    else if (currentRole == 'admin') newRole = 'delivery';

    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({'role': newRole});
      await _loadUsers();
    } catch (e) {
      debugPrint('[ADMIN USERS] Toggle role failed: $e');
    }
  }

  Future<void> _deleteUser(BuildContext context, String uid, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete User', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
        content: RichText(
          text: TextSpan(
            style: const TextStyle(fontFamily: 'Outfit', fontSize: 14, color: Colors.black87),
            children: [
              const TextSpan(text: 'Are you sure you want to permanently delete '),
              TextSpan(text: name, style: const TextStyle(fontWeight: FontWeight.bold)),
              const TextSpan(text: '? This action cannot be undone.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(fontFamily: 'Outfit')),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.delete_forever_rounded, size: 16),
            label: const Text('Delete', style: TextStyle(fontFamily: 'Outfit')),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).delete();
      await _loadUsers();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('User "$name" deleted successfully'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      debugPrint('[ADMIN USERS] Delete failed: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete user: $e')),
        );
      }
    }
  }

  Widget _userActionBtn({required IconData icon, required Color color, required String tooltip, required VoidCallback onTap}) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SUPPORT INBOX SECTION
// ─────────────────────────────────────────────────────────────────────────────

class _SupportSection extends StatefulWidget {
  const _SupportSection();

  @override
  State<_SupportSection> createState() => _SupportSectionState();
}

class _SupportSectionState extends State<_SupportSection> {
  List<Map<String, dynamic>> _tickets = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  Future<void> _loadTickets() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('support_tickets')
          .get();
      final docs = snap.docs.map((d) {
        final data = d.data();
        data['id'] = d.id;
        return data;
      }).toList();

      // Sort by createdAt descending in Dart
      docs.sort((a, b) {
        final aTs = a['createdAt'];
        final bTs = b['createdAt'];
        if (aTs == null && bTs == null) return 0;
        if (aTs == null) return 1;
        if (bTs == null) return -1;
        final aDate = (aTs as Timestamp).toDate();
        final bDate = (bTs as Timestamp).toDate();
        return bDate.compareTo(aDate);
      });

      if (mounted) {
        setState(() {
          _tickets = docs;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('[ADMIN SUPPORT] Failed to load tickets: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showTicketDetailsDialog(BuildContext context, Map<String, dynamic> ticket) {
    final ticketId = ticket['id'] as String;
    final replies = ticket['replies'] as List? ?? [];
    final replyController = TextEditingController();
    bool isSaving = false;
    String status = ticket['status'] ?? 'Open';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Support Ticket: ${ticket['subject'] ?? 'Inquiry'}'),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              content: SizedBox(
                width: 600,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'From: ${ticket['name'] ?? 'N/A'} (${ticket['email'] ?? 'N/A'})',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: (status == 'Open' ? Theme.of(context).colorScheme.primary : Colors.black12).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: status == 'Open' ? Theme.of(context).colorScheme.primary : Colors.black54,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text('Message:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(ticket['message'] ?? '', style: const TextStyle(height: 1.4, fontSize: 13)),
                      const Divider(height: 32),
                      const Text('Replies History:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      if (replies.isEmpty)
                        const Text('No replies sent yet.', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey, fontSize: 12))
                      else
                        ...replies.map((r) {
                          final sender = r['sender'] ?? 'Admin';
                          final text = r['message'] ?? '';
                          final timeVal = r['timestamp'];
                          final dt = timeVal is Timestamp
                              ? timeVal.toDate()
                              : (timeVal is String ? DateTime.tryParse(timeVal) ?? DateTime.now() : DateTime.now());
                          
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            color: sender == 'Admin' ? Theme.of(context).colorScheme.primary.withOpacity(0.08) : Colors.black.withOpacity(0.03),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(sender, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                      Text(
                                        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}',
                                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(text, style: const TextStyle(fontSize: 12)),
                                ],
                              ),
                            ),
                          );
                        }),
                      if (status == 'Open') ...[
                        const Divider(height: 32),
                        const Text('Send a Reply:', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: replyController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            hintText: 'Type your reply message here...',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
                if (status == 'Open') ...[
                  ElevatedButton(
                    onPressed: () async {
                      try {
                        await FirebaseFirestore.instance.collection('support_tickets').doc(ticketId).update({
                          'status': 'Closed',
                        });
                        setDialogState(() {
                          status = 'Closed';
                        });
                        await _loadTickets();
                      } catch (_) {}
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.grey, foregroundColor: Colors.white),
                    child: const Text('Close Ticket'),
                  ),
                  ElevatedButton(
                    onPressed: isSaving ? null : () async {
                      final text = replyController.text.trim();
                      if (text.isEmpty) return;

                      setDialogState(() {
                        isSaving = true;
                      });

                      try {
                        final newReply = {
                          'sender': 'Admin',
                          'message': text,
                          'timestamp': Timestamp.now(),
                        };

                        await FirebaseFirestore.instance.collection('support_tickets').doc(ticketId).update({
                          'replies': FieldValue.arrayUnion([newReply]),
                        });

                        final customerUid = ticket['userId'] as String? ?? '';
                        if (customerUid.isNotEmpty) {
                          final notifRef = FirebaseFirestore.instance
                              .collection('users')
                              .doc(customerUid)
                              .collection('notifications')
                              .doc();
                          
                          await notifRef.set({
                            'id': notifRef.id,
                            'title': 'New Support Ticket Reply',
                            'body': 'Admin replied to your inquiry "${ticket['subject']}": $text',
                            'type': 'support',
                            'read': false,
                            'createdAt': FieldValue.serverTimestamp(),
                          });
                        }

                        await _loadTickets();

                        if (context.mounted) {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Support ticket reply sent successfully')),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to reply: $e')),
                          );
                        }
                      } finally {
                        setDialogState(() {
                          isSaving = false;
                        });
                      }
                    },
                    child: const Text('Send Reply'),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isPhone = size.width < 750;

    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_tickets.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.support_agent_rounded, size: 64, color: theme.colorScheme.onSurface.withOpacity(0.2)),
            const SizedBox(height: 16),
            Text('No support tickets found', style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.4), fontSize: 16, fontFamily: 'Outfit')),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('${_tickets.length} total tickets', style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withOpacity(0.5), fontFamily: 'Outfit')),
              const Spacer(),
              IconButton(onPressed: _loadTickets, icon: const Icon(Icons.refresh_rounded), tooltip: 'Refresh'),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: isPhone
                ? ListView.builder(
                    itemCount: _tickets.length,
                    itemBuilder: (context, index) {
                      final ticket = _tickets[index];
                      final name = ticket['name'] ?? 'N/A';
                      final email = ticket['email'] ?? 'N/A';
                      final subject = ticket['subject'] ?? 'N/A';
                      final status = ticket['status'] ?? 'Open';

                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),

                        ),
                        child: InkWell(
                          onTap: () => _showTicketDetailsDialog(context, ticket),
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        subject,
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: (status == 'Open' ? Theme.of(context).colorScheme.primary : Colors.black12).withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        status,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: status == 'Open' ? Theme.of(context).colorScheme.primary : Colors.black54,
                                          fontFamily: 'Outfit',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Icon(Icons.person_outline_rounded, size: 16, color: theme.colorScheme.onSurface.withOpacity(0.4)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        name,
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'Outfit'),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.mail_outline_rounded, size: 16, color: theme.colorScheme.onSurface.withOpacity(0.4)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        email,
                                        style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withOpacity(0.6), fontFamily: 'Outfit'),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  )
                : Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9F9FB),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                          ),
                          child: const Row(
                            children: [
                              Expanded(flex: 2, child: Text('Customer Name', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Outfit'))),
                              Expanded(flex: 2, child: Text('Email Address', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Outfit'))),
                              Expanded(flex: 3, child: Text('Subject', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Outfit'))),
                              Expanded(child: Text('Status', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Outfit'))),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView.separated(
                            itemCount: _tickets.length,
                            separatorBuilder: (_, __) => Divider(height: 1, color: Colors.black.withOpacity(0.04)),
                            itemBuilder: (context, index) {
                              final ticket = _tickets[index];
                              final name = ticket['name'] ?? 'N/A';
                              final email = ticket['email'] ?? 'N/A';
                              final subject = ticket['subject'] ?? 'N/A';
                              final status = ticket['status'] ?? 'Open';

                              return InkWell(
                                onTap: () => _showTicketDetailsDialog(context, ticket),
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  child: Row(
                                    children: [
                                      Expanded(flex: 2, child: Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'Outfit'), overflow: TextOverflow.ellipsis)),
                                      Expanded(flex: 2, child: Text(email, style: const TextStyle(fontSize: 12, fontFamily: 'Outfit'), overflow: TextOverflow.ellipsis)),
                                      Expanded(flex: 3, child: Text(subject, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withOpacity(0.6), fontFamily: 'Outfit'), overflow: TextOverflow.ellipsis)),
                                      Expanded(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: (status == 'Open' ? Theme.of(context).colorScheme.primary : Colors.black12).withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            status,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: status == 'Open' ? Theme.of(context).colorScheme.primary : Colors.black54,
                                              fontFamily: 'Outfit',
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CONFIGURATION / SETTINGS SECTION
// ─────────────────────────────────────────────────────────────────────────────

class _SettingsSection extends StatefulWidget {
  const _SettingsSection();

  @override
  State<_SettingsSection> createState() => _SettingsSectionState();
}

class _SettingsSectionState extends State<_SettingsSection> {
  final _formKey = GlobalKey<FormState>();
  final _storeNameController = TextEditingController();
  final _supportEmailController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _currencySymbolController = TextEditingController();
  final _cloudNameController = TextEditingController();
  final _uploadPresetController = TextEditingController();
  final _cloudinary = CloudinaryService();
  
  bool _loading = true;
  bool _enableReviews = true;
  bool _showOutOfStock = false;
  bool _requireEmailVerification = false;
  bool _enableFreeShipping = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    String supportEmail = 'support@babyshophub.com';
    String contactPhone = '+1 (555) 019-2834';
    String currencySymbol = '\$';
    bool enableReviews = true;
    bool showOutOfStock = false;
    bool requireEmailVerification = false;
    bool enableFreeShipping = true;

    try {
      final snap = await FirebaseFirestore.instance.collection('admin_settings').doc('store').get();
      if (snap.exists) {
        final data = snap.data();
        if (data != null) {
          supportEmail = data['supportEmail'] ?? supportEmail;
          contactPhone = data['contactPhone'] ?? contactPhone;
          currencySymbol = data['currencySymbol'] ?? currencySymbol;
          enableReviews = data['enableReviews'] ?? enableReviews;
          showOutOfStock = data['showOutOfStock'] ?? showOutOfStock;
          requireEmailVerification = data['requireEmailVerification'] ?? requireEmailVerification;
          enableFreeShipping = data['enableFreeShipping'] ?? enableFreeShipping;
        }
      }
    } catch (e) {
      debugPrint('[ADMIN SETTINGS] Failed to load firestore settings: $e');
    }

    if (mounted) {
      setState(() {
        _supportEmailController.text = supportEmail;
        _contactPhoneController.text = contactPhone;
        _currencySymbolController.text = currencySymbol;
        _enableReviews = enableReviews;
        _showOutOfStock = showOutOfStock;
        _requireEmailVerification = requireEmailVerification;
        _enableFreeShipping = enableFreeShipping;
        _loading = false;
      });
    }
  }

  Future<void> _saveAllSettings() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final emailVal = _supportEmailController.text.trim();
    final phoneVal = _contactPhoneController.text.trim();
    final newName = "$emailVal ($phoneVal)";

    try {
      await FirebaseFirestore.instance.collection('admin_settings').doc('store').set({
        'supportEmail': emailVal,
        'contactPhone': phoneVal,
        'currencySymbol': _currencySymbolController.text.trim(),
        'enableReviews': _enableReviews,
        'showOutOfStock': _showOutOfStock,
        'requireEmailVerification': _requireEmailVerification,
        'enableFreeShipping': _enableFreeShipping,
      }, SetOptions(merge: true));

      // Update the name everywhere for the current admin user
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'displayName': newName,
        });
      }
    } catch (e) {
      debugPrint('[ADMIN SETTINGS] Failed to save firestore settings: $e');
    }
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('support_email', emailVal);
    await prefs.setString('contact_phone', phoneVal);
    await prefs.setString('currency_symbol', _currencySymbolController.text.trim());
    await prefs.setBool('enable_reviews', _enableReviews);
    await prefs.setBool('show_out_of_stock', _showOutOfStock);
    await prefs.setBool('require_email_verification', _requireEmailVerification);
    await prefs.setBool('enable_free_shipping', _enableFreeShipping);
    
    if (mounted) {
      setState(() => _loading = false);
      Provider.of<ShopProvider>(context, listen: false).updateCurrency(_currencySymbolController.text.trim());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('All Settings saved successfully!'),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) return const Center(child: CircularProgressIndicator());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Store Settings & Preferences',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                    fontFamily: 'Outfit',
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Configure your storefront branding, core policies, and storage configurations below.',
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                    fontFamily: 'Outfit',
                  ),
                ),
                const SizedBox(height: 24),
                
                // 1. General Settings Card
                _buildSectionHeader('General Info & Branding', Icons.storefront_rounded),
                const SizedBox(height: 12),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _supportEmailController,
                          decoration: const InputDecoration(
                            labelText: 'Support Email Address',
                            prefixIcon: Icon(Icons.mail_outline_rounded),
                          ),
                          style: const TextStyle(fontFamily: 'Outfit', fontSize: 14),
                          validator: (val) => val == null || val.trim().isEmpty ? 'Enter Support Email' : null,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: _contactPhoneController,
                                decoration: const InputDecoration(
                                  labelText: 'Contact Phone Number',
                                  prefixIcon: Icon(Icons.phone_iphone_rounded),
                                ),
                                style: const TextStyle(fontFamily: 'Outfit', fontSize: 14),
                                validator: (val) => val == null || val.trim().isEmpty ? 'Enter Phone Number' : null,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: _currencySymbolController,
                                decoration: const InputDecoration(
                                  labelText: 'Currency Symbol',
                                  prefixIcon: Icon(Icons.payments_rounded),
                                ),
                                style: const TextStyle(fontFamily: 'Outfit', fontSize: 14),
                                validator: (val) => val == null || val.trim().isEmpty ? 'Symbol' : null,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // 2. Business Logic Toggles
                _buildSectionHeader('Store Policy & Features', Icons.rule_rounded),
                const SizedBox(height: 12),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    child: Column(
                      children: [
                        _buildSwitchTile(
                          title: 'Enable Customer Reviews',
                          subtitle: 'Allow users to submit ratings and feedback on products.',
                          value: _enableReviews,
                          onChanged: (val) => setState(() => _enableReviews = val),
                        ),
                        const Divider(height: 1, indent: 16, endIndent: 16),
                        _buildSwitchTile(
                          title: 'Show Out-of-Stock Products',
                          subtitle: 'Display items with 0 stock on the search and category catalog.',
                          value: _showOutOfStock,
                          onChanged: (val) => setState(() => _showOutOfStock = val),
                        ),
                        const Divider(height: 1, indent: 16, endIndent: 16),
                        _buildSwitchTile(
                          title: 'Require Email Verification',
                          subtitle: 'Users must verify their email address before placing an order.',
                          value: _requireEmailVerification,
                          onChanged: (val) => setState(() => _requireEmailVerification = val),
                        ),
                        const Divider(height: 1, indent: 16, endIndent: 16),
                        _buildSwitchTile(
                          title: 'Enable Free Shipping Promotion',
                          subtitle: 'Highlight free shipping options for orders qualifying at checkout.',
                          value: _enableFreeShipping,
                          onChanged: (val) => setState(() => _enableFreeShipping = val),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // 4. Save Button
                ElevatedButton.icon(
                  onPressed: _saveAllSettings,
                  icon: const Icon(Icons.save_rounded, size: 20),
                  label: const Text('Save All Settings', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            fontFamily: 'Outfit',
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile.adaptive(
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'Outfit')),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.black38, fontFamily: 'Outfit')),
      value: value,
      activeColor: Theme.of(context).colorScheme.primary,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      onChanged: onChanged,
    );
  }
}

class _RevenueTrendChart extends StatelessWidget {
  final List<double> revenueData;
  final List<String> labels;

  const _RevenueTrendChart({
    required this.revenueData,
    required this.labels,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9FB),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Revenue Analytics',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Weekly sales trend (USD)',
                    style: TextStyle(fontSize: 11, color: Colors.black38, fontFamily: 'Outfit'),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '+12.4% this week',
                  style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return CustomPaint(
                  size: Size(constraints.maxWidth, constraints.maxHeight),
                  painter: _ChartPainter(
                    revenueData: revenueData,
                    labels: labels,
                    primaryColor: Theme.of(context).colorScheme.primary,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  final List<double> revenueData;
  final List<String> labels;
  final Color primaryColor;

  _ChartPainter({
    required this.revenueData,
    required this.labels,
    required this.primaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double paddingLeft = 35.0;
    final double paddingBottom = 20.0;
    final double chartWidth = size.width - paddingLeft;
    final double chartHeight = size.height - paddingBottom;

    if (revenueData.isEmpty) return;

    final double maxVal = revenueData.reduce((a, b) => a > b ? a : b);
    final double range = maxVal == 0 ? 1.0 : maxVal;

    // Draw horizontal grid lines and Y labels
    final int gridLinesCount = 3;
    final Paint gridPaint = Paint()
      ..color = Colors.black.withOpacity(0.04)
      ..strokeWidth = 1.0;

    final TextPainter textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    for (int i = 0; i <= gridLinesCount; i++) {
      final double y = chartHeight - (i * (chartHeight / gridLinesCount));
      canvas.drawLine(Offset(paddingLeft, y), Offset(size.width, y), gridPaint);

      final double val = (i * (range / gridLinesCount));
      textPainter.text = TextSpan(
        text: '\$${val.toStringAsFixed(0)}',
        style: const TextStyle(color: Colors.black38, fontSize: 9, fontFamily: 'Outfit'),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(0, y - textPainter.height / 2));
    }

    // Calculate points
    final double stepX = chartWidth / (revenueData.length - 1);
    final List<Offset> points = [];
    for (int i = 0; i < revenueData.length; i++) {
      final double x = paddingLeft + (i * stepX);
      final double y = chartHeight - (revenueData[i] / range) * chartHeight;
      points.add(Offset(x, y));
    }

    // Draw gradient fill below line
    final Path fillPath = Path();
    fillPath.moveTo(paddingLeft, chartHeight);
    for (int i = 0; i < points.length; i++) {
      if (i == 0) {
        fillPath.lineTo(points[i].dx, points[i].dy);
      } else {
        final double prevX = points[i - 1].dx;
        final double prevY = points[i - 1].dy;
        final double currX = points[i].dx;
        final double currY = points[i].dy;
        fillPath.cubicTo(
          prevX + stepX / 2, prevY,
          currX - stepX / 2, currY,
          currX, currY,
        );
      }
    }
    fillPath.lineTo(points.last.dx, chartHeight);
    fillPath.close();

    final Paint fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          primaryColor.withOpacity(0.35),
          primaryColor.withOpacity(0.01),
        ],
      ).createShader(Rect.fromLTRB(paddingLeft, 0, size.width, chartHeight));
    canvas.drawPath(fillPath, fillPaint);

    // Draw line
    final Path linePath = Path();
    for (int i = 0; i < points.length; i++) {
      if (i == 0) {
        linePath.moveTo(points[i].dx, points[i].dy);
      } else {
        final double prevX = points[i - 1].dx;
        final double prevY = points[i - 1].dy;
        final double currX = points[i].dx;
        final double currY = points[i].dy;
        linePath.cubicTo(
          prevX + stepX / 2, prevY,
          currX - stepX / 2, currY,
          currX, currY,
        );
      }
    }

    final Paint linePaint = Paint()
      ..color = primaryColor
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(linePath, linePaint);

    // Draw glowing circles and X labels
    final Paint pointOutlinePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final Paint pointPaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.fill;

    for (int i = 0; i < points.length; i++) {
      canvas.drawCircle(points[i], 5.0, pointOutlinePaint);
      canvas.drawCircle(points[i], 3.5, pointPaint);

      textPainter.text = TextSpan(
        text: labels[i],
        style: const TextStyle(color: Colors.black38, fontSize: 9, fontFamily: 'Outfit'),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(points[i].dx - textPainter.width / 2, chartHeight + 6),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _CategoryDistributionChart extends StatelessWidget {
  final Map<String, int> categoryCounts;

  const _CategoryDistributionChart({required this.categoryCounts});

  @override
  Widget build(BuildContext context) {
    final total = categoryCounts.values.fold(0, (sum, val) => sum + val);

    return Container(
      height: 220,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9FB),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Category Distribution',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
          ),
          const SizedBox(height: 2),
          const Text(
            'Product counts by store category',
            style: TextStyle(fontSize: 11, color: Colors.black38, fontFamily: 'Outfit'),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              physics: const NeverScrollableScrollPhysics(),
              children: categoryCounts.entries.map((entry) {
                final cat = entry.key;
                final count = entry.value;
                final double percent = total == 0 ? 0.0 : count / total;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 70,
                        child: Text(
                          cat,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, fontFamily: 'Outfit'),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: percent,
                            minHeight: 6,
                            backgroundColor: Colors.black.withOpacity(0.04),
                            valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 20,
                        child: Text(
                          '$count',
                          textAlign: TextAlign.end,
                          style: const TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
