import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import '../models/product.dart';
import '../models/order_model.dart';
import '../services/shop_provider.dart';
import '../services/auth_provider.dart';

class ProductDetailsScreen extends StatefulWidget {
  final Product product;
  final String initialTab;
  final bool showReviewForm;

  const ProductDetailsScreen({
    super.key,
    required this.product,
    this.initialTab = 'About',
    this.showReviewForm = false,
  });

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  bool _canReview = false;
  bool _isCheckingEligibility = true;
  bool _showReviewForm = false;
  
  double _formRating = 5.0;
  final _commentController = TextEditingController();
  bool _isSubmittingReview = false;
  
  int _currentImageIndex = 0;
  bool _isDescriptionExpanded = false;
  String _selectedTab = 'About'; // 'About', 'Gallery', 'Review'
  final PageController _pageController = PageController();
  final DraggableScrollableController _draggableController = DraggableScrollableController();
  double _sheetSize = 0.68;

  @override
  void dispose() {
    _pageController.dispose();
    _draggableController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab;
    _showReviewForm = widget.showReviewForm;
    _checkReviewEligibility();
    _draggableController.addListener(() {
      if (mounted) {
        setState(() {
          _sheetSize = _draggableController.size;
        });
      }
    });
  }

  Future<void> _checkReviewEligibility() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _canReview = false;
          _isCheckingEligibility = false;
        });
      }
      return;
    }

    try {
      final ordersSnap = await FirebaseFirestore.instance
          .collection('orders')
          .where('userId', isEqualTo: user.uid)
          .get();

      bool eligible = false;
      for (var doc in ordersSnap.docs) {
        final order = OrderModel.fromMap(doc.id, doc.data());
        if (order.currentStatus == 'Delivered') {
          if (order.items.any((item) => item.id == widget.product.id)) {
            eligible = true;
            break;
          }
        }
      }

      if (mounted) {
        setState(() {
          _canReview = eligible;
          _isCheckingEligibility = false;
        });
      }
    } catch (e) {
      debugPrint('Error checking review eligibility: $e');
      if (mounted) {
        setState(() {
          _canReview = false;
          _isCheckingEligibility = false;
        });
      }
    }
  }

  Future<void> _submitReview() async {
    final user = FirebaseAuth.instance.currentUser;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (user == null) return;

    final comment = _commentController.text.trim();
    if (comment.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please write a review comment')),
      );
      return;
    }

    setState(() {
      _isSubmittingReview = true;
    });

    try {
      final reviewsRef = FirebaseFirestore.instance.collection('reviews');
      
      // 1. Add review doc
      await reviewsRef.add({
        'productId': widget.product.id,
        'userId': user.uid,
        'user': authProvider.currentUser?.displayName ?? 'Verified Customer',
        'rating': _formRating,
        'comment': comment,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 2. Fetch all reviews for this product to update statistics
      final allReviewsSnap = await reviewsRef.where('productId', isEqualTo: widget.product.id).get();
      final list = allReviewsSnap.docs;
      final count = list.length;
      final double totalRating = list.fold(0.0, (sum, d) => sum + (d.data()['rating'] ?? 0.0));
      final double avgRating = count > 0 ? totalRating / count : 5.0;

      // 3. Update products document
      await FirebaseFirestore.instance.collection('products').doc(widget.product.id).update({
        'rating': double.parse(avgRating.toStringAsFixed(1)),
        'reviewsCount': count,
      });

      // 4. Force shop provider refresh
      final shopProvider = Provider.of<ShopProvider>(context, listen: false);
      await shopProvider.refreshProducts();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Review submitted successfully! Thank you.')),
        );
        setState(() {
          _showReviewForm = false;
          _commentController.clear();
          _isSubmittingReview = false;
        });
      }
    } catch (e) {
      debugPrint('Error submitting review: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit review: $e')),
        );
        setState(() {
          _isSubmittingReview = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shop = Provider.of<ShopProvider>(context);
    
    final updatedProduct = shop.products.firstWhere(
      (p) => p.id == widget.product.id,
      orElse: () => widget.product,
    );

    final isWish = shop.isProductWishlisted(updatedProduct.id);
    final isOutOfStock = updatedProduct.stock == 0;

    // Spec indicators dynamically built
    final specItems = [
      {'icon': Icons.baby_changing_station_rounded, 'title': 'Age Range', 'value': updatedProduct.category == 'Baby Food' ? '6m+' : '0m+'},
      {'icon': Icons.eco_outlined, 'title': 'Material', 'value': updatedProduct.category == 'Toys' ? 'Beechwood' : 'Organic'},
      {'icon': Icons.check_circle_outline_rounded, 'title': 'Safety', 'value': 'Approved'},
      {'icon': Icons.inventory_2_outlined, 'title': 'Stock', 'value': '${updatedProduct.stock} left'},
    ];

    final double screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 1. Sliding Image Header PageView
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: 0,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (_sheetSize > 0.5) {
                  _draggableController.animateTo(0.30, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                } else {
                  _draggableController.animateTo(0.68, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                }
              },
              onVerticalDragUpdate: (details) {
                final double dy = details.primaryDelta ?? 0.0;
                final double deltaSize = dy / screenHeight;
                _draggableController.jumpTo((_draggableController.size - deltaSize).clamp(0.30, 0.95));
              },
              onVerticalDragEnd: (details) {
                final double currentSize = _draggableController.size;
                if (currentSize > 0.30 && currentSize < 0.95) {
                  if (currentSize < 0.50) {
                    _draggableController.animateTo(0.30, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                  } else if (currentSize < 0.80) {
                    _draggableController.animateTo(0.68, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                  } else {
                    _draggableController.animateTo(0.95, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                  }
                }
              },
              child: PageView.builder(
                controller: _pageController,
                itemCount: updatedProduct.imageUrls.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentImageIndex = index;
                  });
                },
                itemBuilder: (context, index) {
                  return Image.network(
                    updatedProduct.imageUrls[index],
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.child_care_rounded, size: 80),
                  );
                },
              ),
            ),
          ),

          // Thumbnails row overlapping the bottom edge, animating in sync with sheet
          Positioned(
            bottom: (screenHeight * _sheetSize) + 15,
            left: 20,
            right: 20,
            height: 55,
            child: Center(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    updatedProduct.imageUrls.length,
                    (index) => GestureDetector(
                      onTap: () {
                        _pageController.animateToPage(
                          index,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 5),
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _currentImageIndex == index
                                ? theme.colorScheme.primary
                                : Colors.white,
                            width: 2.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            updatedProduct.imageUrls[index],
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: Colors.grey[200],
                              child: const Icon(Icons.image_rounded, size: 16, color: Colors.grey),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 2. Scrollable Details Sheet
          Positioned.fill(
            child: DraggableScrollableSheet(
              controller: _draggableController,
              initialChildSize: 0.68,
              minChildSize: 0.30,
              maxChildSize: 0.95,
              snap: true,
              snapSizes: const [0.30, 0.68, 0.95],
              builder: (context, scrollController) {
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('reviews')
                    .where('productId', isEqualTo: updatedProduct.id)
                    .snapshots(),
                builder: (context, snapshot) {
                  final List<Review> dynamicReviews = [];
                  final Map<String, int> starDistribution = {'1': 0, '2': 0, '3': 0, '4': 0, '5': 0};

                  if (snapshot.hasData) {
                    for (var doc in snapshot.data!.docs) {
                      final data = doc.data();
                      final double rVal = (data['rating'] ?? 5.0) as double;
                      final rInt = rVal.round().clamp(1, 5);
                      starDistribution[rInt.toString()] = (starDistribution[rInt.toString()] ?? 0) + 1;

                      final created = data['createdAt'] != null
                          ? (data['createdAt'] as Timestamp).toDate()
                          : DateTime.now();

                      dynamicReviews.add(Review(
                        user: data['user'] ?? 'Verified Customer',
                        rating: rVal,
                        comment: data['comment'] ?? '',
                        date: '${created.day}/${created.month}/${created.year}',
                      ));
                    }
                  } else {
                    dynamicReviews.addAll(updatedProduct.reviews);
                    for (var rev in updatedProduct.reviews) {
                      final rInt = rev.rating.round().clamp(1, 5);
                      starDistribution[rInt.toString()] = (starDistribution[rInt.toString()] ?? 0) + 1;
                    }
                  }

                  return Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 20,
                          offset: Offset(0, -10),
                        ),
                      ],
                    ),
                    child: ListView(
                      physics: const ClampingScrollPhysics(),
                      controller: scrollController,
                      padding: const EdgeInsets.only(left: 24.0, right: 24.0, top: 32.0, bottom: 110.0),
                      children: [
                        // Title
                        Text(
                          updatedProduct.name,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: Colors.black87,
                            fontFamily: 'Outfit',
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Location/Category subtitle
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined, size: 16, color: Colors.black54),
                            const SizedBox(width: 4),
                            const Text(
                              'BabyShopHub Premium Catalog',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.black54,
                                fontFamily: 'Outfit',
                              ),
                            ),
                            const Spacer(),
                            const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                            const SizedBox(width: 4),
                            Text(
                              '${updatedProduct.rating}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // 3. Tab Selector
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: ['About', 'Gallery', 'Review'].map((tab) {
                            final isSelected = _selectedTab == tab;
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedTab = tab;
                                });
                              },
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    tab,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      color: isSelected ? theme.colorScheme.primary : Colors.black45,
                                      fontFamily: 'Outfit',
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: isSelected ? 40 : 0,
                                    height: 3,
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary,
                                      borderRadius: BorderRadius.circular(1.5),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 24),

                        // Conditionally render contents based on _selectedTab
                        if (_selectedTab == 'About') ...[
                          // Specs Row: Row of rounded vertical cards
                          SizedBox(
                            height: 90,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: specItems.length,
                              itemBuilder: (context, index) {
                                final spec = specItems[index];
                                return Container(
                                  width: 95,
                                  margin: const EdgeInsets.only(right: 12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF9F9FB),
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(spec['icon'] as IconData, color: Colors.black87, size: 24),
                                      const SizedBox(height: 8),
                                      Text(
                                        spec['value'] as String,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        spec['title'] as String,
                                        style: const TextStyle(
                                          fontSize: 9,
                                          color: Colors.black38,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Product Description with Read More
                          const Text(
                            'Description',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Colors.black87,
                              fontFamily: 'Outfit',
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            updatedProduct.description,
                            maxLines: _isDescriptionExpanded ? null : 3,
                            overflow: _isDescriptionExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black54,
                                height: 1.5,
                                fontFamily: 'Outfit',
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _isDescriptionExpanded = !_isDescriptionExpanded;
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4.0),
                                child: Text(
                                  _isDescriptionExpanded ? 'Read Less' : 'Read More..',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Divider(),
                          const SizedBox(height: 16),
                          // Premium Store card
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: theme.colorScheme.primary.withOpacity(0.08),
                                child: Icon(Icons.storefront_rounded, color: theme.colorScheme.primary, size: 24),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'BabyShopHub Official Store',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, fontFamily: 'Outfit'),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${(shop.products.fold(0.0, (sum, p) => sum + p.rating) / (shop.products.isEmpty ? 1 : shop.products.length)).toStringAsFixed(1)} (Store Rating)',
                                          style: const TextStyle(color: Colors.black54, fontSize: 12, fontFamily: 'Outfit'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                  icon: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary.withOpacity(0.08),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.chat_bubble_outline_rounded, color: theme.colorScheme.primary, size: 18),
                                  ),
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Contacting store support...')),
                                    );
                                  },
                                ),
                            ],
                          ),
                        ] else if (_selectedTab == 'Gallery') ...[
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: updatedProduct.imageUrls.length,
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 1.0,
                            ),
                            itemBuilder: (context, index) {
                              return ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: GestureDetector(
                                  onTap: () {
                                    _pageController.animateToPage(
                                      index,
                                      duration: const Duration(milliseconds: 300),
                                      curve: Curves.easeInOut,
                                    );
                                  },
                                  child: Image.network(
                                    updatedProduct.imageUrls[index],
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      color: Colors.grey[100],
                                      child: const Icon(Icons.image_not_supported_rounded, color: Colors.grey),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ] else if (_selectedTab == 'Review') ...[
                          // Review submission panel
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Reviews',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.black87,
                                  fontFamily: 'Outfit',
                                ),
                              ),
                              if (!_showReviewForm)
                                TextButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _showReviewForm = true;
                                    });
                                  },
                                  icon: const Icon(Icons.rate_review_rounded, size: 18),
                                  label: const Text('Add Review'),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          if (_showReviewForm) ...[
                            Card(
                              color: const Color(0xFFF9F9FB),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('Rating:', style: TextStyle(fontWeight: FontWeight.bold)),
                                        IconButton(
                                          icon: const Icon(Icons.close, size: 18),
                                          onPressed: () {
                                            setState(() {
                                              _showReviewForm = false;
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: List.generate(5, (index) {
                                        final starVal = index + 1;
                                        return IconButton(
                                          icon: Icon(
                                            starVal <= _formRating
                                                ? Icons.star_rounded
                                                : Icons.star_border_rounded,
                                            color: Colors.amber,
                                            size: 32,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _formRating = starVal.toDouble();
                                            });
                                          },
                                        );
                                      }),
                                    ),
                                    const SizedBox(height: 10),
                                    TextFormField(
                                      controller: _commentController,
                                      maxLines: 2,
                                      decoration: const InputDecoration(
                                        labelText: 'Write your experience...',
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed: _isSubmittingReview ? null : _submitReview,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.black87,
                                          foregroundColor: Colors.white,
                                        ),
                                        child: _isSubmittingReview
                                            ? const SizedBox(
                                                width: 20,
                                                height: 20,
                                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                              )
                                            : const Text('Submit'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Reviews feed list
                          if (dynamicReviews.isEmpty)
                            const Text(
                              'No reviews yet. Be the first to share your thoughts!',
                              style: TextStyle(fontStyle: FontStyle.italic, color: Colors.black38),
                            )
                          else
                            ...dynamicReviews.map((rev) => Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF9F9FB),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            rev.user,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                          Text(
                                            rev.date,
                                            style: const TextStyle(fontSize: 11, color: Colors.black38),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: List.generate(
                                          5,
                                          (i) => Icon(
                                            Icons.star_rounded,
                                            color: i < rev.rating ? Colors.amber : Colors.grey.shade300,
                                            size: 14,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        rev.comment,
                                        style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.4),
                                      ),
                                    ],
                                  ),
                                )),
                        ]
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),

          // 3. Overlay Back and Wishlist buttons
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Curved back button
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Colors.black87),
                  ),
                ),

                // Floating circular wishlist heart
                GestureDetector(
                  onTap: () => shop.toggleWishlist(updatedProduct.id),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      isWish ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: isWish ? Colors.redAccent : Colors.black87,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 4. Sticky Bottom Action Bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Price',
                          style: TextStyle(fontSize: 12, color: Colors.black38),
                        ),
                        Text(
                          '${Provider.of<ShopProvider>(context, listen: false).currencySymbol}${updatedProduct.price.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Colors.black87,
                            fontFamily: 'Outfit',
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: ElevatedButton(
                      onPressed: isOutOfStock
                          ? null
                          : () {
                              shop.addToCart(updatedProduct);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('${updatedProduct.name} added to cart!'),
                                  backgroundColor: theme.colorScheme.primary,
                                ),
                              );
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isOutOfStock ? Colors.grey : Colors.black87,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: Text(
                        isOutOfStock ? 'Out of Stock' : 'Add to Cart',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Outfit',
                        ),
                      ),
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
