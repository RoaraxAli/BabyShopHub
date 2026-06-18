class Product {
  final String id;
  final String name;
  final String category;
  final String description;
  final double price;
  final String imageUrl;
  final List<String> imageUrls;
  final double rating;
  final int reviewsCount;
  int stock;
  bool isWishlisted;
  final List<Review> reviews;
  final Map<String, int> ratingDistribution;

  Product({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.price,
    required this.imageUrl,
    List<String>? imageUrls,
    required this.rating,
    required this.reviewsCount,
    required this.stock,
    this.isWishlisted = false,
    required this.reviews,
    this.ratingDistribution = const {'1': 0, '2': 0, '3': 0, '4': 0, '5': 0},
  }) : imageUrls = imageUrls ?? [imageUrl];

  Product copyWith({
    String? id,
    String? name,
    String? category,
    String? description,
    double? price,
    String? imageUrl,
    List<String>? imageUrls,
    double? rating,
    int? reviewsCount,
    int? stock,
    bool? isWishlisted,
    List<Review>? reviews,
    Map<String, int>? ratingDistribution,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      description: description ?? this.description,
      price: price ?? this.price,
      imageUrl: imageUrl ?? this.imageUrl,
      imageUrls: imageUrls ?? this.imageUrls,
      rating: rating ?? this.rating,
      reviewsCount: reviewsCount ?? this.reviewsCount,
      stock: stock ?? this.stock,
      isWishlisted: isWishlisted ?? this.isWishlisted,
      reviews: reviews ?? this.reviews,
      ratingDistribution: ratingDistribution ?? this.ratingDistribution,
    );
  }

  static List<Product> getSeedProducts() {
    return [
      Product(
        id: 'p1',
        name: 'Organic Cotton Onesie Set',
        category: 'Clothing',
        description: 'Super soft, 100% organic cotton onesies designed for delicate newborn skin. Includes 3 pastel colors with easy snap closures for quick diaper changes.',
        price: 24.99,
        imageUrl: 'https://images.unsplash.com/photo-1522771739844-6a9f6d5f14af?auto=format&fit=crop&q=80&w=400',
        rating: 4.8,
        reviewsCount: 128,
        stock: 15,
        reviews: [
          Review(user: 'Amara K.', rating: 5, comment: 'So soft and holds up great in the wash!', date: 'May 12, 2026'),
          Review(user: 'David L.', rating: 4, comment: 'Sizing runs slightly large, but excellent quality.', date: 'April 28, 2026'),
        ],
      ),
      Product(
        id: 'p2',
        name: 'Premium Huggy Diapers (Size 2)',
        category: 'Diapers',
        description: 'Ultra-absorbent baby diapers featuring a unique leak-guard pocket and a wetness indicator strip. Free from fragrances, parabens, and elemental chlorine.',
        price: 34.50,
        imageUrl: 'https://images.unsplash.com/photo-1555252333-9f8e92e65df9?auto=format&fit=crop&q=80&w=400',
        rating: 4.9,
        reviewsCount: 342,
        stock: 45,
        reviews: [
          Review(user: 'Sarah M.', rating: 5, comment: 'Zero leaks overnight! The best diapers we have used.', date: 'May 20, 2026'),
        ],
      ),
      Product(
        id: 'p3',
        name: 'Organic Sweet Potato & Apple Puree',
        category: 'Baby Food',
        description: 'Smooth, tasty organic baby puree in convenient squeezable travel pouches. No added sugar or artificial preservatives. Recommended for babies 6+ months.',
        price: 12.99,
        imageUrl: 'https://images.unsplash.com/photo-1596701062351-8c2c14d1fdd0?auto=format&fit=crop&q=80&w=400',
        rating: 4.6,
        reviewsCount: 89,
        stock: 5, // Low stock simulation
        reviews: [
          Review(user: 'Jessica P.', rating: 5, comment: 'My son absolutely loves this flavor!', date: 'May 18, 2026'),
        ],
      ),
      Product(
        id: 'p4',
        name: 'Wooden Stacking Activity Toy',
        category: 'Toys',
        description: 'Crafted from sustainable beechwood and finished with baby-safe water-based paints. Promotes motor skill development, size sequencing, and coordination.',
        price: 18.99,
        imageUrl: 'https://images.unsplash.com/photo-1587654780291-39c9404d746b?auto=format&fit=crop&q=80&w=400',
        rating: 4.7,
        reviewsCount: 56,
        stock: 0, // OUT OF STOCK to simulate Wishlist Notification!
        reviews: [
          Review(user: 'Tariq S.', rating: 5, comment: 'Beautiful toy! Well made and durable.', date: 'May 04, 2026'),
        ],
      ),
      Product(
        id: 'p5',
        name: 'Gentle Tear-Free Baby Shampoo',
        category: 'Bath',
        description: 'Nourishing tear-free formula blended with natural chamomile extract. Clinically tested to gently cleanse without drying out sensitive infant scalps.',
        price: 9.99,
        imageUrl: 'https://images.unsplash.com/photo-1608571423902-eed4a5ad8108?auto=format&fit=crop&q=80&w=400',
        rating: 4.8,
        reviewsCount: 204,
        stock: 22,
        reviews: [
          Review(user: 'Olivia W.', rating: 5, comment: 'Smells beautiful and is so gentle on baby\'s eyes.', date: 'May 15, 2026'),
        ],
      ),
    ];
  }
}

class Review {
  final String user;
  final double rating;
  final String comment;
  final String date;

  Review({
    required this.user,
    required this.rating,
    required this.comment,
    required this.date,
  });
}
