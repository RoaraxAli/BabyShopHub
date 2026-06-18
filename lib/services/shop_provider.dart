import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../models/product.dart';
import '../models/cart.dart';

class ShopProvider extends ChangeNotifier {
  final List<Product> _products = Product.getSeedProducts();
  final List<CartItem> _cart = [];
  final List<String> _wishlist = [];
  bool _isLoading = false;

  String? _appliedPromoCode;
  double _promoDiscount = 0.0;

  List<Product> get products => _products;
  List<CartItem> get cart => _cart;
  List<String> get wishlist => _wishlist;
  bool get isLoading => _isLoading;
  String? get appliedPromoCode => _appliedPromoCode;
  double get promoDiscount => _promoDiscount;

  String _searchQuery = '';
  String _selectedCategory = 'All';

  String get searchQuery => _searchQuery;
  String get selectedCategory => _selectedCategory;

  ShopProvider() {
    _loadProductsFromFirestore();
  }

  // Sync products with Firestore online if available, else fallback to local seed data
  Future<void> _loadProductsFromFirestore() async {
    try {
      var snap = await FirebaseFirestore.instance.collection('products').get();
      if (snap.docs.isEmpty) {
        debugPrint('[SHOP PROVIDER] Products collection is empty. Seeding Firestore...');
        final seeds = Product.getSeedProducts();
        for (var p in seeds) {
          await FirebaseFirestore.instance.collection('products').doc(p.id).set({
            'name': p.name,
            'category': p.category,
            'description': p.description,
            'price': p.price,
            'imageUrl': p.imageUrl,
            'imageUrls': p.imageUrls,
            'rating': p.rating,
            'reviewsCount': p.reviewsCount,
            'stock': p.stock,
            'createdAt': FieldValue.serverTimestamp(),
          });
          // Seed reviews
          for (var r in p.reviews) {
            await FirebaseFirestore.instance.collection('reviews').add({
              'productId': p.id,
              'user': r.user,
              'rating': r.rating,
              'comment': r.comment,
              'createdAt': Timestamp.now(),
            });
          }
        }
        snap = await FirebaseFirestore.instance.collection('products').get();
      }

      if (snap.docs.isNotEmpty) {
        _products.clear();
        for (var doc in snap.docs) {
          final data = doc.data();
          final List<dynamic> urlsData = data['imageUrls'] ?? [];
          final List<String> imageUrls = urlsData.isNotEmpty
              ? urlsData.map((e) => e.toString()).toList()
              : <String>[(data['imageUrl'] ?? '').toString()];
          _products.add(Product(
            id: doc.id,
            name: data['name'] ?? '',
            category: data['category'] ?? '',
            description: data['description'] ?? '',
            price: (data['price'] ?? 0.0) as double,
            imageUrl: data['imageUrl'] ?? '',
            imageUrls: imageUrls,
            rating: (data['rating'] ?? 5.0) as double,
            reviewsCount: (data['reviewsCount'] ?? 0) as int,
            stock: (data['stock'] ?? 0) as int,
            reviews: [],
          ));
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[SHOP PROVIDER ERROR] _loadProductsFromFirestore failed: $e');
    }
  }

  /// Called by admin panel after product add/edit/delete
  Future<void> refreshProducts() => _loadProductsFromFirestore();

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  List<Product> get filteredProducts {
    return _products.where((product) {
      final matchesSearch = product.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          product.description.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory = _selectedCategory == 'All' || product.category == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();
  }

  // --- Cart operations ---
  double get cartSubtotal => _cart.fold(0.0, (sum, item) => sum + item.totalPrice);
  double get cartTotal => (cartSubtotal - _promoDiscount).clamp(0.0, double.infinity);
  int get cartCount => _cart.fold(0, (sum, item) => sum + item.quantity);

  void _recalculateDiscount() {
    if (_appliedPromoCode == null) {
      _promoDiscount = 0.0;
      return;
    }
    final code = _appliedPromoCode!.toUpperCase();
    final sub = cartSubtotal;
    if (code == 'FIRSTBABY') {
      _promoDiscount = sub * 0.15;
    } else if (code == 'BABYSAVE10') {
      if (sub >= 30.0) {
        _promoDiscount = 10.0;
      } else {
        _appliedPromoCode = null;
        _promoDiscount = 0.0;
      }
    } else if (code == 'NEWPARENT') {
      _promoDiscount = sub * 0.20;
    } else {
      _promoDiscount = 0.0;
    }
  }

  String? applyPromoCode(String code) {
    final cleanCode = code.trim().toUpperCase();
    final sub = cartSubtotal;

    if (sub <= 0) {
      return 'Cart is empty';
    }

    if (cleanCode == 'FIRSTBABY') {
      _appliedPromoCode = cleanCode;
      _recalculateDiscount();
      notifyListeners();
      return null;
    } else if (cleanCode == 'BABYSAVE10') {
      if (sub < 30.0) {
        return 'Minimum purchase of \$30.00 required for this code';
      }
      _appliedPromoCode = cleanCode;
      _recalculateDiscount();
      notifyListeners();
      return null;
    } else if (cleanCode == 'NEWPARENT') {
      _appliedPromoCode = cleanCode;
      _recalculateDiscount();
      notifyListeners();
      return null;
    } else {
      return 'Invalid promo code';
    }
  }

  void removePromoCode() {
    _appliedPromoCode = null;
    _promoDiscount = 0.0;
    notifyListeners();
  }

  void addToCart(Product product) {
    final index = _cart.indexWhere((item) => item.product.id == product.id);
    if (index >= 0) {
      if (_cart[index].quantity < product.stock) {
        _cart[index].quantity++;
      }
    } else {
      if (product.stock > 0) {
        _cart.add(CartItem(product: product, quantity: 1));
      }
    }
    _recalculateDiscount();
    notifyListeners();
  }

  void updateCartQuantity(String productId, int quantity) {
    final index = _cart.indexWhere((item) => item.product.id == productId);
    if (index >= 0) {
      if (quantity <= 0) {
        _cart.removeAt(index);
      } else {
        final stockLimit = _cart[index].product.stock;
        _cart[index].quantity = quantity.clamp(1, stockLimit);
      }
      _recalculateDiscount();
      notifyListeners();
    }
  }

  void removeFromCart(String productId) {
    _cart.removeWhere((item) => item.product.id == productId);
    _recalculateDiscount();
    notifyListeners();
  }

  void clearCart() {
    _cart.clear();
    _appliedPromoCode = null;
    _promoDiscount = 0.0;
    notifyListeners();
  }

  // --- Wishlist operations ---
  bool isProductWishlisted(String id) => _wishlist.contains(id);

  Future<void> toggleWishlist(String id, [String? userEmail]) async {
    final email = userEmail ?? FirebaseAuth.instance.currentUser?.email ?? 'anonymous_parent';
    final index = _products.indexWhere((p) => p.id == id);
    if (index >= 0) {
      final p = _products[index];
      if (_wishlist.contains(id)) {
        _wishlist.remove(id);
        p.isWishlisted = false;
        
        // Remove from Firestore wishlists collection
        try {
          final query = await FirebaseFirestore.instance
              .collection('wishlists')
              .where('productId', isEqualTo: id)
              .where('userEmail', isEqualTo: email)
              .get();
          for (var doc in query.docs) {
            await doc.reference.delete();
          }
        } catch (e) {
          debugPrint('[SHOP PROVIDER ERROR] Failed to remove from wishlist: $e');
        }

      } else {
        _wishlist.add(id);
        p.isWishlisted = true;

        // Save to Firestore wishlists collection
        try {
          await FirebaseFirestore.instance.collection('wishlists').add({
            'productId': id,
            'userEmail': email,
            'createdAt': FieldValue.serverTimestamp(),
          });
        } catch (e) {
          debugPrint('[SHOP PROVIDER ERROR] Failed to add to wishlist: $e');
        }
      }
      notifyListeners();
    }
  }

  // --- Zoho SMTP Trigger Helper (Direct HTTP POST to local relay) ---
  Future<void> _triggerZohoEmail(String email, String type, Map<String, dynamic> data) async {
    final String subject;
    final String htmlContent;

    if (type == 'CHECKOUT_SUCCESS') {
      subject = 'Order Confirmed - BabyShopHub';
      final total = (data['total'] ?? 0.0) as double;
      final address = data['address'] ?? '';
      final promoCode = data['promoCode'] as String?;
      final discount = (data['discount'] ?? 0.0) as double;
      String itemsRows = '';
      if (data['items'] != null && data['items'] is List) {
        for (var item in data['items']) {
          final name = item['name'] ?? '';
          final qty = item['quantity'] ?? 1;
          final price = (item['price'] ?? 0.0) as double;
          itemsRows += '<tr><td style="padding:8px;border-bottom:1px solid #eee;">$name (x$qty)</td><td style="padding:8px;border-bottom:1px solid #eee;text-align:right;">' + '\$${(price * qty).toStringAsFixed(2)}' + '</td></tr>';
        }
      }
      String discountRow = '';
      if (promoCode != null && discount > 0) {
        discountRow = '<tr><td style="padding:8px;color:#2e7d32;font-weight:bold;">Discount ($promoCode):</td><td style="padding:8px;text-align:right;color:#2e7d32;font-weight:bold;">-\$${discount.toStringAsFixed(2)}</td></tr>';
      }
      htmlContent = '''
        <div style="font-family:Arial,sans-serif;max-width:600px;margin:0 auto;padding:20px;border:1px solid #eee;border-radius:12px;">
          <h2 style="color:#FF9EAA;text-align:center;">Your Order is Confirmed</h2>
          <p>Thank you for your purchase. We are preparing your baby products with love and care.</p>
          <table style="width:100%;border-collapse:collapse;margin:20px 0;">
            <thead><tr style="background:#f7f7f7;"><th style="padding:8px;text-align:left;border-bottom:2px solid #ddd;">Product</th><th style="padding:8px;text-align:right;border-bottom:2px solid #ddd;">Total</th></tr></thead>
            <tbody>$itemsRows</tbody>
            <tfoot>
              $discountRow
              <tr><td style="padding:8px;font-weight:bold;">Grand Total:</td><td style="padding:8px;font-weight:bold;text-align:right;color:#FF9EAA;">' + '\$${total.toStringAsFixed(2)}' + '</td></tr>
            </tfoot>
          </table>
          <div style="background:#f9f9f9;padding:12px;border-radius:8px;">
            <p style="margin:0;font-size:13px;"><strong>Delivery Address:</strong><br/>$address</p>
          </div>
        </div>
      ''';
    } else if (type == 'WISHLIST_STOCK_ALERT') {
      final name = data['name'] ?? '';
      final price = (data['price'] ?? 0.0) as double;
      final stock = data['stock'] ?? 0;
      subject = 'Back in Stock: $name - BabyShopHub';
      htmlContent = '''
        <div style="font-family:Arial,sans-serif;max-width:600px;margin:0 auto;padding:20px;border:1px solid #eee;border-radius:12px;">
          <h2 style="color:#FF9EAA;text-align:center;">Good News! $name is Back in Stock</h2>
          <p>Hello,</p>
          <p>Your wishlisted item is now available:</p>
          <div style="border:1px solid #eee;border-radius:8px;padding:12px;margin:20px 0;">
            <h3 style="margin:0;color:#333;">$name</h3>
            <p style="margin:4px 0 0;font-weight:bold;color:#FF9EAA;">' + '\$${price.toStringAsFixed(2)}' + '</p>
            <p style="margin:8px 0 0;font-size:12px;color:#2e7d32;font-weight:bold;">Only $stock items left in stock!</p>
          </div>
          <hr style="border:0;border-top:1px solid #eee;margin:20px 0;"/>
          <p style="font-size:11px;color:#999;text-align:center;">BabyShopHub Wishlist Alerts</p>
        </div>
      ''';
    } else {
      subject = 'Notification from BabyShopHub';
      htmlContent = '<p>You have a new notification from BabyShopHub.</p>';
    }

    debugPrint('[SHOP SMTP RELAY] Dispatching $type email to $email');
    try {
      final url = Uri.parse('http://localhost:3000/send-email');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'to': email, 'subject': subject, 'html': htmlContent}),
      ).timeout(const Duration(seconds: 10));
      debugPrint('[SHOP SMTP RELAY] Response: ${response.statusCode} - ${response.body}');
    } catch (e) {
      debugPrint('[SHOP SMTP RELAY] Failed: $e');
    }
  }

  // --- Secure Checkout (Write to Firestore) ---
  Future<String?> processCheckout(String userEmail, String shippingAddress) async {
    _isLoading = true;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 1500));

    final user = FirebaseAuth.instance.currentUser;
    final userId = user?.uid ?? '';

    final itemsList = _cart.map((item) => {
      'id': item.product.id,
      'name': item.product.name,
      'quantity': item.quantity,
      'price': item.product.price,
      'total': item.totalPrice,
      'imageUrl': item.product.imageUrl, // Immutable product snapshot
    }).toList();

    final orderTotal = cartTotal;
    final promoCode = _appliedPromoCode;
    final discountVal = _promoDiscount;

    // 1. Write order details to Firestore with statusHistory and product snapshots
    try {
      await FirebaseFirestore.instance.collection('orders').add({
        'email': userEmail,
        'userId': userId,
        'address': shippingAddress,
        'items': itemsList,
        'total': orderTotal,
        'promoCode': promoCode,
        'discount': discountVal,
        'statusHistory': [
          {
            'status': 'Pending',
            'timestamp': Timestamp.now(),
            'note': 'Order placed by customer',
          }
        ],
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[SHOP PROVIDER ERROR] Order creation failed: $e');
      _isLoading = false;
      notifyListeners();
      return e.toString();
    }

    // 2. Decrement stocks in local memory & Firestore
    for (var cartItem in _cart) {
      final idx = _products.indexWhere((p) => p.id == cartItem.product.id);
      if (idx >= 0) {
        final newStock = (_products[idx].stock - cartItem.quantity).clamp(0, 999);
        _products[idx].stock = newStock;
        
        try {
          await FirebaseFirestore.instance
              .collection('products')
              .doc(cartItem.product.id)
              .update({'stock': newStock});
        } catch (e) {
          debugPrint('[SHOP PROVIDER ERROR] Failed to update stock for ${cartItem.product.id}: $e');
        }
      }
    }

    clearCart();
    _isLoading = false;
    notifyListeners();

    // 3. Trigger checkout success receipt email
    await _triggerZohoEmail(userEmail, 'CHECKOUT_SUCCESS', {
      'items': itemsList,
      'total': orderTotal,
      'address': shippingAddress,
      'promoCode': promoCode,
      'discount': discountVal,
    });

    return null;
  }

  // --- Admin Stock Updates (Listen & Trigger Wishlist Emails) ---
  Future<void> updateProductStock(String productId, int newStock) async {
    final index = _products.indexWhere((p) => p.id == productId);
    if (index >= 0) {
      final product = _products[index];
      final previousStock = product.stock;
      product.stock = newStock;
      notifyListeners();

      // Update in Firestore
      try {
        await FirebaseFirestore.instance
            .collection('products')
            .doc(productId)
            .update({'stock': newStock});
      } catch (e) {
        debugPrint('[SHOP PROVIDER ERROR] Failed to update stock in Firestore: $e');
      }

      // Trigger restock alerts
      if (previousStock == 0 && newStock > 0) {
        // Query Firestore wishlists for all email addresses bookmarked
        try {
          final query = await FirebaseFirestore.instance
              .collection('wishlists')
              .where('productId', isEqualTo: productId)
              .get();

          for (var doc in query.docs) {
            final email = doc.data()['userEmail'];
            if (email != null) {
              await _triggerZohoEmail(email, 'WISHLIST_STOCK_ALERT', {
                'name': product.name,
                'price': product.price,
                'stock': newStock,
              });
            }
          }
        } catch (e) {
          debugPrint('[SHOP PROVIDER ERROR] Wishlist query failed: $e');
          // Local memory fallback trigger
          if (_wishlist.contains(productId)) {
            debugPrint('Mocking Zoho Wishlist Alert: ${product.name} back in stock!');
          }
        }
      }
    }
  }
}
