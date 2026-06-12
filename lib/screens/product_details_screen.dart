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

  const ProductDetailsScreen({
    super.key,
    required this.product,
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

  @override
  void initState() {
    super.initState();
    _checkReviewEligibility();
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
    
    // Find the latest product details from provider to show updated rating/reviewsCount
    final updatedProduct = shop.products.firstWhere(
      (p) => p.id == widget.product.id,
      orElse: () => widget.product,
    );

    final isWish = shop.isProductWishlisted(updatedProduct.id);
    final isOutOfStock = updatedProduct.stock == 0;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(
              isWish ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: isWish ? Colors.redAccent : theme.colorScheme.onSurface,
            ),
            onPressed: () => shop.toggleWishlist(updatedProduct.id),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
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
            // Fallback to static seed reviews
            dynamicReviews.addAll(updatedProduct.reviews);
            for (var rev in updatedProduct.reviews) {
              final rInt = rev.rating.round().clamp(1, 5);
              starDistribution[rInt.toString()] = (starDistribution[rInt.toString()] ?? 0) + 1;
            }
          }

          final totalReviews = dynamicReviews.length;

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Large Product Image block
                Container(
                  height: 280,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.04),
                  ),
                  child: Image.network(
                    updatedProduct.imageUrl,
                    fit: updatedProduct.category == 'Baby Food' ? BoxFit.contain : BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.child_care_rounded, size: 80),
                  ),
                ),

                // Details Container
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category tag
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          updatedProduct.category,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Product Title & Price
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              updatedProduct.name,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Text(
                            '\$${updatedProduct.price.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Ratings Summary block
                      Row(
                        children: [
                          const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
                          const SizedBox(width: 4),
                          Text(
                            '${updatedProduct.rating}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '($totalReviews Customer Reviews)',
                            style: TextStyle(
                              fontSize: 13,
                              color: theme.colorScheme.onSurface.withOpacity(0.5),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Stock Status
                      if (isOutOfStock)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.redAccent.withOpacity(0.2)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline_rounded, color: Colors.redAccent, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Currently Out of Stock',
                                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent, fontSize: 13),
                                    ),
                                    Text(
                                      'Add this product to your wishlist! We will email you automatically the exact moment it is restocked.',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'In Stock (${updatedProduct.stock} items left)',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.green),
                            ),
                          ],
                        ),
                      const SizedBox(height: 20),

                      // Description Paragraph
                      const Text(
                        'About this item',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        updatedProduct.description,
                        style: TextStyle(
                          fontSize: 14,
                          color: theme.colorScheme.onSurface.withOpacity(0.65),
                          height: 1.5,
                        ),
                      ),
                      const Divider(height: 40),

                      // Rating Distribution Section
                      const Text(
                        'Rating Distribution',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      _buildRatingDistribution(starDistribution, totalReviews, theme),
                      const Divider(height: 40),

                      // Customer Reviews Section Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Customer Reviews',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          if (_canReview && !_showReviewForm)
                            TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _showReviewForm = true;
                                });
                              },
                              icon: const Icon(Icons.rate_review_rounded, size: 18),
                              label: const Text('Write a Review'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Review submission inline form
                      if (_showReviewForm) ...[
                        Card(
                          color: theme.colorScheme.primary.withOpacity(0.03),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: theme.colorScheme.primary.withOpacity(0.2)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Your Rating:', style: TextStyle(fontWeight: FontWeight.bold)),
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
                                  maxLines: 3,
                                  decoration: const InputDecoration(
                                    labelText: 'Review comment',
                                    hintText: 'Share your parenting experience with this product...',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _isSubmittingReview ? null : _submitReview,
                                    child: _isSubmittingReview
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                          )
                                        : const Text('Submit Review'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ] else if (_isCheckingEligibility) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Row(
                            children: [
                              SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                              SizedBox(width: 12),
                              Text('Verifying purchase history...', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ] else if (!_canReview) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            '🔒 Verified Purchase Reviewing Only: You can write a customer review for this product after ordering and receiving it.',
                            style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      if (dynamicReviews.isEmpty)
                        Text(
                          'No reviews yet. Be the first to share your thoughts!',
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            color: theme.colorScheme.onSurface.withOpacity(0.4),
                          ),
                        )
                      else
                        ...dynamicReviews.map((rev) => Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              color: theme.colorScheme.surface,
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
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
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: theme.colorScheme.onSurface.withOpacity(0.4),
                                          ),
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
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, -2),
            )
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: isOutOfStock
                    ? () {
                        shop.toggleWishlist(updatedProduct.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              isWish
                                  ? 'Removed from wishlist'
                                  : 'Wishlisted! You will receive an email once in stock.',
                            ),
                            backgroundColor: theme.colorScheme.primary,
                          ),
                        );
                      }
                    : () {
                        shop.addToCart(updatedProduct);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${updatedProduct.name} added to cart!'),
                            action: SnackBarAction(
                              label: 'Undo',
                              textColor: Colors.white,
                              onPressed: () {
                                shop.removeFromCart(updatedProduct.id);
                              },
                            ),
                          ),
                        );
                      },
                icon: Icon(isOutOfStock ? Icons.mail_outline_rounded : Icons.shopping_bag_outlined),
                label: Text(
                  isOutOfStock
                      ? (isWish ? 'Wishlisted (Alert Active)' : 'Notify Me When In Stock')
                      : 'Add to Shopping Cart',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isOutOfStock
                      ? (isWish ? Colors.grey.shade600 : theme.colorScheme.secondary)
                      : theme.colorScheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingDistribution(Map<String, int> starDistribution, int totalReviews, ThemeData theme) {
    return Column(
      children: List.generate(5, (index) {
        final starNum = 5 - index;
        final count = starDistribution[starNum.toString()] ?? 0;
        final double percent = totalReviews > 0 ? count / totalReviews : 0.0;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3.0),
          child: Row(
            children: [
              SizedBox(
                width: 50,
                child: Text(
                  '$starNum Star',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: percent,
                    minHeight: 8,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 30,
                child: Text(
                  count.toString(),
                  style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withOpacity(0.6)),
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
