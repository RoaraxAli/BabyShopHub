# BabyShopHub 🍼

Welcome to BabyShopHub, a premium mobile application tailored for parents to seamlessly shop for baby products, track orders, and interact with sellers. 

## Features
- **User Authentication:** Email/Password & Secure TOTP 2FA.
- **Dynamic Catalog:** Browse categories, view product details, check gallery images.
- **Review System:** Leave product reviews, read verified customer feedback, and see dynamic average store ratings.
- **Cart & Checkout:** Add to cart, apply promo codes, checkout securely via Stripe.
- **Order Tracking:** Track your orders from pending to delivered with live updates.
- **Wishlist & Notifications:** Save favorite items and receive back-in-stock alerts via Email.
- **Admin Panel:** Manage inventory, products, orders, banners, and store vouchers.
- **Delivery App UI:** Specialized interface for delivery personnel to update order statuses dynamically.

## Developer Setup
### Prerequisites
- Flutter SDK (`>=3.24.0`)
- Android SDK (API 34)
- Java JDK 17
- Firebase project configuration

### Installation
1. Clone this repository: `git clone <repo-url>`
2. Fetch dependencies: `flutter pub get`
3. Connect your Firebase Project:
   Ensure `google-services.json` is correctly placed in `android/app/`.

### Building for Release (Android APK)
To build a signed release APK:
```bash
flutter build apk --release
```
The output APK will be available in: `build/app/outputs/flutter-apk/app-release.apk`.

### Firebase Security Rules (Firestore)
Ensure Firestore rules allow read access for users, but restrict write access to authenticated users, and specific admin operations strictly to admin accounts. Ensure `products`, `users`, `reviews`, `categories`, and `orders` collections are initialized.

### Troubleshooting
- **Network Request Failed (AuthError):** Ensure `android.permission.INTERNET` is in the `AndroidManifest.xml` (already implemented).
- **SDK Errors:** Ensure `flutter doctor --android-licenses` is fully accepted and Android SDK location is mapped properly (`flutter config --android-sdk <path>`).

## Maintainer
- Built by Muhammad Ali
