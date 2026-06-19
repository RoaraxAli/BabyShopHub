import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product.dart';
import '../models/cart.dart';
import '../models/category_model.dart';
import '../models/voucher_model.dart';

class ShopProvider extends ChangeNotifier {
  final List<Product> _products = Product.getSeedProducts();
  final List<CartItem> _cart = [];
  final List<String> _wishlist = [];
  bool _isLoading = false;

  String? _appliedPromoCode;
  double _promoDiscount = 0.0;

  final List<CategoryModel> _categories = [];
  final List<VoucherModel> _vouchers = [];

  List<Product> get products => _products;
  List<CartItem> get cart => _cart;
  List<String> get wishlist => _wishlist;
  bool get isLoading => _isLoading;
  String? get appliedPromoCode => _appliedPromoCode;
  double get promoDiscount => _promoDiscount;
  List<CategoryModel> get categories => _categories;
  List<VoucherModel> get vouchers => _vouchers;

  String _searchQuery = '';
  String _selectedCategory = 'All';

  String get searchQuery => _searchQuery;
  String get selectedCategory => _selectedCategory;

  ShopProvider() {
    _loadProductsFromFirestore();
    _loadCategoriesFromFirestore();
    _loadVouchersFromFirestore();
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

  Future<void> _loadCategoriesFromFirestore() async {
    try {
      var snap = await FirebaseFirestore.instance.collection('categories').get();
      if (snap.docs.isEmpty) {
        debugPrint('[SHOP PROVIDER] Categories collection is empty. Seeding Firestore...');
        final seeds = [
          CategoryModel(id: 'c1', name: 'Diapers', imageUrl: 'https://images.unsplash.com/photo-1555252333-9f8e92e65df9?auto=format&fit=crop&q=80&w=400'),
          CategoryModel(id: 'c2', name: 'Baby Food', imageUrl: 'https://images.unsplash.com/photo-1596701062351-8c2c14d1fdd0?auto=format&fit=crop&q=80&w=400'),
          CategoryModel(id: 'c3', name: 'Clothing', imageUrl: 'https://images.unsplash.com/photo-1522771739844-6a9f6d5f14af?auto=format&fit=crop&q=80&w=400'),
          CategoryModel(id: 'c4', name: 'Toys', imageUrl: 'https://images.unsplash.com/photo-1587654780291-39c9404d746b?auto=format&fit=crop&q=80&w=400'),
          CategoryModel(id: 'c5', name: 'Bath', imageUrl: 'https://images.unsplash.com/photo-1608571423902-eed4a5ad8108?auto=format&fit=crop&q=80&w=400'),
        ];
        for (var c in seeds) {
          await FirebaseFirestore.instance.collection('categories').doc(c.id).set(c.toMap());
        }
        snap = await FirebaseFirestore.instance.collection('categories').get();
      }

      if (snap.docs.isNotEmpty) {
        _categories.clear();
        for (var doc in snap.docs) {
          _categories.add(CategoryModel.fromMap(doc.data(), doc.id));
        }
        _saveCategoriesToPrefs();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[SHOP PROVIDER ERROR] _loadCategoriesFromFirestore failed: $e');
      await _loadCategoriesFromPrefs();
    }
  }

  Future<void> _saveCategoriesToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _categories.map((c) => jsonEncode({
        'id': c.id,
        'name': c.name,
        'imageUrl': c.imageUrl,
      })).toList();
      await prefs.setStringList('local_categories', list);
    } catch (err) {
      debugPrint('[SHOP PROVIDER ERROR] _saveCategoriesToPrefs failed: $err');
    }
  }

  Future<void> _loadCategoriesFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('local_categories');
      if (list != null && list.isNotEmpty) {
        _categories.clear();
        for (var item in list) {
          final data = jsonDecode(item);
          _categories.add(CategoryModel(
            id: data['id'] ?? '',
            name: data['name'] ?? '',
            imageUrl: data['imageUrl'] ?? '',
          ));
        }
        notifyListeners();
      } else {
        _loadDefaultSeedCategories();
      }
    } catch (_) {
      _loadDefaultSeedCategories();
    }
  }

  void _loadDefaultSeedCategories() {
    _categories.clear();
    _categories.addAll([
      CategoryModel(id: 'c1', name: 'Diapers', imageUrl: 'https://images.unsplash.com/photo-1555252333-9f8e92e65df9?auto=format&fit=crop&q=80&w=400'),
      CategoryModel(id: 'c2', name: 'Baby Food', imageUrl: 'https://images.unsplash.com/photo-1596701062351-8c2c14d1fdd0?auto=format&fit=crop&q=80&w=400'),
      CategoryModel(id: 'c3', name: 'Clothing', imageUrl: 'https://images.unsplash.com/photo-1522771739844-6a9f6d5f14af?auto=format&fit=crop&q=80&w=400'),
      CategoryModel(id: 'c4', name: 'Toys', imageUrl: 'https://images.unsplash.com/photo-1587654780291-39c9404d746b?auto=format&fit=crop&q=80&w=400'),
      CategoryModel(id: 'c5', name: 'Bath', imageUrl: 'https://images.unsplash.com/photo-1608571423902-eed4a5ad8108?auto=format&fit=crop&q=80&w=400'),
    ]);
    notifyListeners();
  }

  Future<void> addCategory(String name, String imageUrl) async {
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final newCat = CategoryModel(id: tempId, name: name, imageUrl: imageUrl);
    _categories.add(newCat);
    _saveCategoriesToPrefs();
    notifyListeners();

    try {
      final docRef = await FirebaseFirestore.instance.collection('categories').add({
        'name': name,
        'imageUrl': imageUrl,
      });
      final idx = _categories.indexWhere((c) => c.id == tempId);
      if (idx >= 0) {
        _categories[idx] = CategoryModel(id: docRef.id, name: name, imageUrl: imageUrl);
        _saveCategoriesToPrefs();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[SHOP PROVIDER ERROR] Failed to persist category to Firestore: $e');
    }
  }

  Future<void> deleteCategory(String id) async {
    _categories.removeWhere((c) => c.id == id);
    _saveCategoriesToPrefs();
    notifyListeners();

    try {
      if (!id.startsWith('temp_')) {
        await FirebaseFirestore.instance.collection('categories').doc(id).delete();
      }
    } catch (e) {
      debugPrint('[SHOP PROVIDER ERROR] Failed to delete category from Firestore: $e');
    }
  }

  Future<void> _loadVouchersFromFirestore() async {
    try {
      var snap = await FirebaseFirestore.instance.collection('vouchers').get();
      if (snap.docs.isEmpty) {
        debugPrint('[SHOP PROVIDER] Vouchers collection is empty. Seeding Firestore...');
        final seeds = [
          VoucherModel(id: 'v1', code: 'FIRSTBABY', type: 'percentage', value: 0.15, minPurchase: 0.0),
          VoucherModel(id: 'v2', code: 'BABYSAVE10', type: 'flat', value: 10.0, minPurchase: 30.0),
          VoucherModel(id: 'v3', code: 'NEWPARENT', type: 'percentage', value: 0.20, minPurchase: 0.0),
        ];
        for (var v in seeds) {
          await FirebaseFirestore.instance.collection('vouchers').doc(v.id).set(v.toMap());
        }
        snap = await FirebaseFirestore.instance.collection('vouchers').get();
      }

      if (snap.docs.isNotEmpty) {
        _vouchers.clear();
        for (var doc in snap.docs) {
          _vouchers.add(VoucherModel.fromMap(doc.data(), doc.id));
        }
        _saveVouchersToPrefs();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[SHOP PROVIDER ERROR] _loadVouchersFromFirestore failed: $e');
      await _loadVouchersFromPrefs();
    }
  }

  Future<void> _saveVouchersToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _vouchers.map((v) => jsonEncode({
        'id': v.id,
        'code': v.code,
        'type': v.type,
        'value': v.value,
        'minPurchase': v.minPurchase,
      })).toList();
      await prefs.setStringList('local_vouchers', list);
    } catch (err) {
      debugPrint('[SHOP PROVIDER ERROR] _saveVouchersToPrefs failed: $err');
    }
  }

  Future<void> _loadVouchersFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('local_vouchers');
      if (list != null && list.isNotEmpty) {
        _vouchers.clear();
        for (var item in list) {
          final data = jsonDecode(item);
          _vouchers.add(VoucherModel(
            id: data['id'] ?? '',
            code: data['code'] ?? '',
            type: data['type'] ?? 'percentage',
            value: (data['value'] as num? ?? 0.0).toDouble(),
            minPurchase: (data['minPurchase'] as num? ?? 0.0).toDouble(),
          ));
        }
        notifyListeners();
      } else {
        _loadDefaultSeedVouchers();
      }
    } catch (_) {
      _loadDefaultSeedVouchers();
    }
  }

  void _loadDefaultSeedVouchers() {
    _vouchers.clear();
    _vouchers.addAll([
      VoucherModel(id: 'v1', code: 'FIRSTBABY', type: 'percentage', value: 0.15, minPurchase: 0.0),
      VoucherModel(id: 'v2', code: 'BABYSAVE10', type: 'flat', value: 10.0, minPurchase: 30.0),
      VoucherModel(id: 'v3', code: 'NEWPARENT', type: 'percentage', value: 0.20, minPurchase: 0.0),
    ]);
    notifyListeners();
  }

  Future<void> addVoucher(String code, String type, double value, double minPurchase) async {
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final cleanCode = code.trim().toUpperCase();
    final newVoucher = VoucherModel(id: tempId, code: cleanCode, type: type, value: value, minPurchase: minPurchase);
    _vouchers.add(newVoucher);
    _saveVouchersToPrefs();
    notifyListeners();

    try {
      final docRef = await FirebaseFirestore.instance.collection('vouchers').add({
        'code': cleanCode,
        'type': type,
        'value': value,
        'minPurchase': minPurchase,
      });
      final idx = _vouchers.indexWhere((v) => v.id == tempId);
      if (idx >= 0) {
        _vouchers[idx] = VoucherModel(id: docRef.id, code: cleanCode, type: type, value: value, minPurchase: minPurchase);
        _saveVouchersToPrefs();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[SHOP PROVIDER ERROR] Failed to persist voucher to Firestore: $e');
    }
  }

  Future<void> deleteVoucher(String id) async {
    _vouchers.removeWhere((v) => v.id == id);
    _saveVouchersToPrefs();
    notifyListeners();

    try {
      if (!id.startsWith('temp_')) {
        await FirebaseFirestore.instance.collection('vouchers').doc(id).delete();
      }
    } catch (e) {
      debugPrint('[SHOP PROVIDER ERROR] Failed to delete voucher from Firestore: $e');
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
    final index = _vouchers.indexWhere((v) => v.code.toUpperCase() == code);
    if (index >= 0) {
      final v = _vouchers[index];
      if (sub >= v.minPurchase) {
        if (v.type == 'percentage') {
          _promoDiscount = sub * v.value;
        } else {
          _promoDiscount = v.value;
        }
      } else {
        _appliedPromoCode = null;
        _promoDiscount = 0.0;
      }
    } else {
      _appliedPromoCode = null;
      _promoDiscount = 0.0;
    }
  }

  String? applyPromoCode(String code) {
    final cleanCode = code.trim().toUpperCase();
    final sub = cartSubtotal;

    if (sub <= 0) {
      return 'Cart is empty';
    }

    final index = _vouchers.indexWhere((v) => v.code.toUpperCase() == cleanCode);
    if (index >= 0) {
      final v = _vouchers[index];
      if (sub < v.minPurchase) {
        return 'Minimum purchase of \$${v.minPurchase.toStringAsFixed(2)} required for this code';
      }
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

  // --- Stripe Checkout Redirect Flow ---
  Future<String?> initiateStripeCheckout(String userEmail, String shippingAddress) async {
    _isLoading = true;
    notifyListeners();

    final user = FirebaseAuth.instance.currentUser;
    final userId = user?.uid ?? '';

    final itemsList = _cart.map((item) => {
      'id': item.product.id,
      'name': item.product.name,
      'quantity': item.quantity,
      'price': item.product.price,
      'total': item.totalPrice,
      'imageUrl': item.product.imageUrl,
    }).toList();

    final orderTotal = cartTotal;
    final promoCode = _appliedPromoCode;
    final discountVal = _promoDiscount;

    try {
      // 1. Create order in Firestore as Pending
      final orderRef = await FirebaseFirestore.instance.collection('orders').add({
        'email': userEmail,
        'userId': userId,
        'address': shippingAddress,
        'items': itemsList,
        'total': orderTotal,
        'promoCode': promoCode,
        'discount': discountVal,
        'status': 'Pending',
        'statusHistory': [
          {
            'status': 'Pending',
            'timestamp': Timestamp.now(),
            'note': 'Stripe checkout initiated',
          }
        ],
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 2. Call Next.js API route to create Checkout Session
      final response = await http.post(
        Uri.parse('http://localhost:3000/api/checkout'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'items': _cart.map((item) => {
            'product': {
              'name': item.product.name,
              'price': item.product.price,
              'image': item.product.imageUrl ?? '',
            },
            'quantity': item.quantity,
          }).toList(),
          'userId': userId,
          'email': userEmail,
          'address': shippingAddress,
          'orderId': orderRef.id,
          'redirectUrl': 'http://localhost:3000',
        }),
      );

      if (response.statusCode == 200) {
        final resBody = jsonDecode(response.body);
        final stripeUrl = resBody['url'] as String?;
        if (stripeUrl != null) {
          clearCart();
          _isLoading = false;
          notifyListeners();
          
          await launchUrl(Uri.parse(stripeUrl), mode: LaunchMode.externalApplication);
          return null; // success
        }
      }
      throw Exception('Failed to generate Stripe Checkout: ${response.body}');
    } catch (e) {
      debugPrint('[STRIPE CHECKOUT ERROR] $e');
      _isLoading = false;
      notifyListeners();
      return e.toString();
    }
  }
}
