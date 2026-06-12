import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/shop_provider.dart';
import '../services/auth_provider.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/product_card.dart';
import 'product_details_screen.dart';
import 'cart_screen.dart';
import 'profile_screen.dart';
import 'admin_panel.dart';
import 'wishlist_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _bottomNavIndex = 0;
  bool _isInitLoading = true;
  final TextEditingController _searchController = TextEditingController();

  final List<String> _categories = ['All', 'Diapers', 'Baby Food', 'Clothing', 'Toys', 'Bath'];

  @override
  void initState() {
    super.initState();
    _triggerInitialShimmerEffect();
  }

  Future<void> _triggerInitialShimmerEffect() async {
    await Future.delayed(const Duration(milliseconds: 1000));
    if (mounted) {
      setState(() {
        _isInitLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shop = Provider.of<ShopProvider>(context);
    final auth = Provider.of<AuthProvider>(context);
    final isAdmin = auth.currentUser?.role == 'admin';

    // HomeScreen is always user-facing. Admin panel is a separate route.
    final List<Widget> pages = [
      _buildWebLandingPage(theme, shop),
      _buildShopFeed(theme, shop),
      const ProfileScreen(),
    ];

    final List<String> titles = [
      'BabyShopHub Home',
      'Marketplace Catalog',
      'My Profile Settings',
    ];

    final activeIndex = _bottomNavIndex.clamp(0, pages.length - 1);

    return Scaffold(
      appBar: AppBar(
        leading: isAdmin
            ? IconButton(
                tooltip: 'Back to Admin Panel',
                icon: const Icon(Icons.admin_panel_settings_rounded),
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (context) => const AdminPanel()),
                  );
                },
              )
            : null,
        title: Text(
          titles[activeIndex],
          style: TextStyle(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w900,
            fontSize: 22,
            letterSpacing: 0.5,
            fontFamily: 'Outfit',
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite_border_rounded, size: 28),
            tooltip: 'My Wishlist',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const WishlistScreen()),
              );
            },
          ),
          const SizedBox(width: 4),
          Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.shopping_bag_outlined, size: 28),
                  onPressed: () {
                    // Navigate to CartScreen as a dedicated slide-up panel!
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => Scaffold(
                          appBar: AppBar(
                            title: const Text('Shopping Cart'),
                            leading: IconButton(
                              icon: const Icon(Icons.arrow_back_ios_new_rounded),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ),
                          body: const CartScreen(),
                        ),
                      ),
                    );
                  },
                ),
                if (shop.cartCount > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        '${shop.cartCount}',
                        style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
              ],
            ),
          const SizedBox(width: 12),
        ],
      ),
      body: pages[activeIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 16,
              offset: const Offset(0, -4),
            )
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: activeIndex,
          onTap: (index) {
            setState(() {
              _bottomNavIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: theme.colorScheme.surface,
          selectedItemColor: theme.colorScheme.primary,
          unselectedItemColor: theme.colorScheme.onSurface.withOpacity(0.4),
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'Outfit'),
          unselectedLabelStyle: const TextStyle(fontSize: 11, fontFamily: 'Outfit'),
          items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.home_outlined),
                    activeIcon: Icon(Icons.home_filled),
                    label: 'Home',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.shopping_bag_outlined),
                    activeIcon: Icon(Icons.shopping_bag),
                    label: 'Shop',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.person_outline),
                    activeIcon: Icon(Icons.person),
                    label: 'Profile',
                  ),
                ],
        ),
      ),
    );
  }

  // --- Premium Web Landing Page ---
  Widget _buildWebLandingPage(ThemeData theme, ShopProvider shop) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 40.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Hero Promo Banner
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.secondary.withOpacity(0.9),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.child_care_rounded, size: 48, color: Colors.white),
                const SizedBox(height: 16),
                const Text(
                  'Pure Comfort for Your\nPrecious Little One',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    fontFamily: 'Outfit',
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Discover organic baby formula, cotton onesies, soft toys, and leak-proof diapers crafted with absolute clinical safety.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.9),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _bottomNavIndex = 1;
                    });
                  },
                  icon: const Icon(Icons.arrow_right_alt_rounded, color: Colors.white),
                  label: const Text('Explore Catalog', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                    side: const BorderSide(color: Colors.white, width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. Service Highlights propositions grid
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.85,
              children: [
                _buildValueCard(theme, Icons.local_shipping_outlined, 'Free Shipping', 'No minimum spend required.'),
                _buildValueCard(theme, Icons.security_outlined, 'MFA Security', 'Google Authenticator enabled.'),
                _buildValueCard(theme, Icons.cached_rounded, '30-Day Return', 'Easy refunds on unopened boxes.'),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 3. Featured Categories Quick view
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Featured Categories',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _bottomNavIndex = 1;
                    });
                  },
                  child: const Text('See All'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildCategoryBannerCard(theme, Icons.baby_changing_station, 'Diapers', 'Diapers'),
                _buildCategoryBannerCard(theme, Icons.restaurant, 'Baby Food', 'Baby Food'),
                _buildCategoryBannerCard(theme, Icons.checkroom_rounded, 'Fashion Onesies', 'Clothing'),
                _buildCategoryBannerCard(theme, Icons.smart_toy_outlined, 'Sustainable Toys', 'Toys'),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // 4. Parent Testimonials Section
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.0),
            child: Text(
              'Trusted by Parents Worldwide',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Card(
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: List.generate(
                        5,
                        (index) => const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '"This is by far the most convenient infant platform we have used. The MFA setup gives us complete peace of mind, and the delivery alerts are incredibly prompt."',
                      style: TextStyle(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        color: theme.colorScheme.onBackground.withOpacity(0.7),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Sarah M., New Mother',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    )
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildValueCard(ThemeData theme, IconData icon, String title, String subtitle) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 26, color: theme.colorScheme.primary),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, fontFamily: 'Outfit'),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 9, color: theme.colorScheme.onBackground.withOpacity(0.5)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryBannerCard(ThemeData theme, IconData icon, String label, String filterKey) {
    return GestureDetector(
      onTap: () {
        final shop = Provider.of<ShopProvider>(context, listen: false);
        shop.setCategory(filterKey);
        setState(() {
          _bottomNavIndex = 1;
        });
      },
      child: Container(
        width: 100,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.onBackground.withOpacity(0.06)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 30, color: theme.colorScheme.secondary),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
            )
          ],
        ),
      ),
    );
  }

  // --- Shop Catalog Feed ---
  Widget _buildShopFeed(ThemeData theme, ShopProvider shop) {
    final filtered = shop.filteredProducts;

    return RefreshIndicator(
      onRefresh: () async {
        setState(() {
          _isInitLoading = true;
        });
        await _triggerInitialShimmerEffect();
      },
      color: theme.colorScheme.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Floating Home button to return to Landing page
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    _bottomNavIndex = 0;
                  });
                },
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 14),
                label: const Text('Back to Home Landing'),
              ),
            ),

            // Prominent search header block
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextFormField(
                controller: _searchController,
                onChanged: (val) => shop.setSearchQuery(val),
                decoration: InputDecoration(
                  hintText: 'Search baby formula, diapers, toys...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _searchController.clear();
                            shop.setSearchQuery('');
                          },
                        )
                      : null,
                ),
              ),
            ),

            // Horizontal categories row
            SizedBox(
              height: 48,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                itemBuilder: (context, index) {
                  final cat = _categories[index];
                  final isSelected = shop.selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: ChoiceChip(
                      label: Text(cat),
                      selected: isSelected,
                      onSelected: (_) {
                        shop.setCategory(cat);
                      },
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : theme.colorScheme.onBackground.withOpacity(0.6),
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontFamily: 'Outfit',
                      ),
                      selectedColor: theme.colorScheme.primary,
                      backgroundColor: theme.colorScheme.surface,
                      checkmarkColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: isSelected ? Colors.transparent : theme.colorScheme.onBackground.withOpacity(0.08),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // Shimmer logic grid
            _isInitLoading
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: 4,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.72,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemBuilder: (context, index) => const SkeletonProductCard(),
                    ),
                  )
                : filtered.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 60.0),
                          child: Column(
                            children: [
                              Icon(Icons.warning_amber_rounded, size: 48, color: theme.colorScheme.primary),
                              const SizedBox(height: 12),
                              Text(
                                'No matching products found',
                                style: TextStyle(color: theme.colorScheme.onBackground.withOpacity(0.4)),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: filtered.length,
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.72,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemBuilder: (context, index) {
                            final p = filtered[index];
                            return ProductCard(
                              product: p,
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => ProductDetailsScreen(product: p),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
          ],
        ),
      ),
    );
  }
}
