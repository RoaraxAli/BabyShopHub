import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_provider.dart';
import '../services/cloudinary_service.dart';
import '../theme/theme_provider.dart';
import '../models/user.dart';
import 'auth/login_screen.dart';
import 'admin_panel.dart';
import 'saved_addresses_screen.dart';
import 'order_history_screen.dart';
import 'wishlist_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.currentUser;

    if (user == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline_rounded, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Please login to manage your settings',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              },
              child: const Text('Go to Login'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 16.0, bottom: 110.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Admin Return Button
          if (user.role == 'admin') ...[
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const AdminPanel()),
                );
              },
              icon: const Icon(Icons.admin_panel_settings_rounded),
              label: const Text('Return to Admin Panel'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF9EAA),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          // Profile Mini Header
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: theme.colorScheme.primary.withOpacity(0.12),
                    backgroundImage: user.profilePicture != null
                        ? NetworkImage(user.profilePicture!)
                        : null,
                    child: user.profilePicture == null
                        ? Icon(Icons.person_outline_rounded, size: 36, color: theme.colorScheme.primary)
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.displayName,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user.email,
                          style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6), fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  // Notifications button removed
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          const Text(
            'Application Settings',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          const SizedBox(height: 8),

          // Settings Items List
          _buildSettingsButton(
            context,
            icon: Icons.person_outline_rounded,
            title: 'Profile Details',
            subtitle: 'Manage your name, email, and avatar selections',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const ProfileDetailsSubScreen()),
              );
            },
          ),
          _buildSettingsButton(
            context,
            icon: Icons.receipt_long_outlined,
            title: 'My Orders',
            subtitle: 'Track status and review your order history',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const OrderHistoryScreen()),
              );
            },
          ),
          _buildSettingsButton(
            context,
            icon: Icons.favorite_border_rounded,
            title: 'My Wishlist',
            subtitle: 'View products you saved and check their availability',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const WishlistScreen()),
              );
            },
          ),
          _buildSettingsButton(
            context,
            icon: Icons.location_on_outlined,
            title: 'Saved Addresses',
            subtitle: 'Manage default shipping and delivery options',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const SavedAddressesScreen()),
              );
            },
          ),
          _buildSettingsButton(
            context,
            icon: Icons.palette_outlined,
            title: 'App Theme Customizer',
            subtitle: 'Change colors, hex options, and dark mode toggles',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const ThemeCustomizerSubScreen()),
              );
            },
          ),
          _buildSettingsButton(
            context,
            icon: Icons.security_rounded,
            title: '2FA Security Configuration',
            subtitle: 'Secure logins with two-factor authentication',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const TwoFactorSetupSubScreen()),
              );
            },
          ),
          _buildSettingsButton(
            context,
            icon: Icons.info_outline_rounded,
            title: 'About Us',
            subtitle: 'Read about BabyShopHub and our clinical safety standards',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const AboutUsSubScreen()),
              );
            },
          ),
          _buildSettingsButton(
            context,
            icon: Icons.contact_support_outlined,
            title: 'Contact Customer Support',
            subtitle: 'Get in touch with customer support',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const ContactUsSubScreen()),
              );
            },
          ),

          const SizedBox(height: 24),

          // Log Out Button
          OutlinedButton.icon(
            onPressed: () {
              auth.logout();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );
            },
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            label: const Text('Log Out', style: TextStyle(color: Colors.redAccent)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: const BorderSide(color: Colors.redAccent),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSettingsButton(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: Icon(icon, color: theme.colorScheme.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }

  void _showNotificationsBottomSheet(BuildContext context, AuthProvider auth) {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return StatefulBuilder(
              builder: (context, setModalState) {
                final currentNotifications = auth.currentUser?.notifications ?? [];
                
                return Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.all(8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Notifications',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          if (currentNotifications.any((n) => !n.read))
                            TextButton(
                              onPressed: () async {
                                for (var n in currentNotifications) {
                                  if (!n.read) {
                                    await auth.markNotificationAsRead(n.id);
                                  }
                                }
                                setModalState(() {});
                              },
                              child: const Text('Mark all as read'),
                            ),
                        ],
                      ),
                    ),
                    const Divider(),
                    Expanded(
                      child: currentNotifications.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.notifications_none_rounded, size: 64, color: theme.colorScheme.onSurface.withOpacity(0.2)),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No notifications yet',
                                    style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface.withOpacity(0.5)),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              controller: scrollController,
                              itemCount: currentNotifications.length,
                              itemBuilder: (context, index) {
                                final n = currentNotifications[index];
                                final iconData = n.type == 'order'
                                    ? Icons.local_shipping_rounded
                                    : n.type == 'support'
                                        ? Icons.support_agent_rounded
                                        : Icons.notifications_rounded;
                                
                                return Container(
                                  color: n.read ? null : theme.colorScheme.primary.withOpacity(0.04),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: n.read
                                          ? Colors.grey.shade200
                                          : theme.colorScheme.primary.withOpacity(0.1),
                                      child: Icon(
                                        iconData,
                                        color: n.read ? Colors.grey : theme.colorScheme.primary,
                                      ),
                                    ),
                                    title: Text(
                                      n.title,
                                      style: TextStyle(
                                        fontWeight: n.read ? FontWeight.normal : FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 4),
                                        Text(n.body, style: const TextStyle(fontSize: 12)),
                                      ],
                                    ),
                                    trailing: !n.read
                                        ? IconButton(
                                            icon: const Icon(Icons.check_circle_outline_rounded, color: Colors.green),
                                            onPressed: () async {
                                              await auth.markNotificationAsRead(n.id);
                                              setModalState(() {});
                                            },
                                            tooltip: 'Mark as read',
                                          )
                                        : null,
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

// ==========================================
// 1. Profile Details Sub-Screen
// ==========================================
class ProfileDetailsSubScreen extends StatefulWidget {
  const ProfileDetailsSubScreen({super.key});

  @override
  State<ProfileDetailsSubScreen> createState() => _ProfileDetailsSubScreenState();
}

class _ProfileDetailsSubScreenState extends State<ProfileDetailsSubScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    _nameController.text = auth.currentUser?.displayName ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.currentUser;

    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile Details'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Avatar Selection Block
              const Text(
                'Profile Picture',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 56,
                      backgroundColor: theme.colorScheme.primary.withOpacity(0.12),
                      backgroundImage: user.profilePicture != null
                          ? NetworkImage(user.profilePicture!)
                          : null,
                      child: user.profilePicture == null
                          ? Icon(Icons.person_outline_rounded, size: 56, color: theme.colorScheme.primary)
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: () async {
                          final picker = ImagePicker();
                          final source = await showDialog<ImageSource>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Select Photo Source'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, ImageSource.camera),
                                  child: const Text('Camera'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, ImageSource.gallery),
                                  child: const Text('Gallery'),
                                ),
                              ],
                            ),
                          );
                          if (source == null) return;
                          final file = await picker.pickImage(source: source);
                          if (file == null) return;
                          
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Uploading photo to Cloudinary...')),
                          );
                          
                          final cloudinary = CloudinaryService();
                          await cloudinary.init();
                          final url = await cloudinary.uploadImage(file);
                          if (url != null) {
                            await auth.updateProfilePicture(url);
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Profile picture updated successfully!'), backgroundColor: Colors.green),
                            );
                          } else {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Failed to upload picture.'), backgroundColor: Colors.redAccent),
                            );
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 40),

              TextFormField(
                controller: _nameController,
                validator: (val) => val == null || val.trim().isEmpty ? 'Enter full name' : null,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  if (!_formKey.currentState!.validate()) return;
                  await auth.updateDisplayName(_nameController.text.trim());
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Display name updated successfully.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  Navigator.of(context).pop();
                },
                child: const Text('Save Details'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 2. Theme Customizer Sub-Screen
// ==========================================
class ThemeCustomizerSubScreen extends StatefulWidget {
  const ThemeCustomizerSubScreen({super.key});

  @override
  State<ThemeCustomizerSubScreen> createState() => _ThemeCustomizerSubScreenState();
}

class _ThemeCustomizerSubScreenState extends State<ThemeCustomizerSubScreen> {
  final _primaryHexController = TextEditingController();
  final _secondaryHexController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    _primaryHexController.text = _colorToHex(themeProvider.primaryColor);
    _secondaryHexController.text = _colorToHex(themeProvider.secondaryColor);
  }

  String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
  }

  Color? _hexToColor(String hex) {
    try {
      var cleaned = hex.replaceAll('#', '').trim();
      if (cleaned.length == 6) {
        cleaned = 'FF$cleaned';
      }
      if (cleaned.length == 8) {
        return Color(int.parse(cleaned, radix: 16));
      }
    } catch (_) {}
    return null;
  }

  void _applyCustomTheme() {
    final primaryColor = _hexToColor(_primaryHexController.text);
    final secondaryColor = _hexToColor(_secondaryHexController.text);
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    if (primaryColor != null && secondaryColor != null) {
      themeProvider.updateCustomTheme(primaryColor, secondaryColor);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Theme colors applied successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid hex format (use e.g. #FF9EAA)'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('App Theme Customizer'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Select Predefined Presets',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(
                ThemeProvider.presets.length,
                (idx) => ChoiceChip(
                  label: Text(ThemeProvider.presets[idx]['name'] as String),
                  selected: false,
                  onSelected: (_) {
                    themeProvider.setPreset(idx);
                    _primaryHexController.text = _colorToHex(themeProvider.primaryColor);
                    _secondaryHexController.text = _colorToHex(themeProvider.secondaryColor);
                  },
                ),
              ),
            ),
            const Divider(height: 40),

            const Text(
              'Custom Color HEX Settings',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _primaryHexController,
                    decoration: const InputDecoration(
                      labelText: 'Primary Color',
                      prefixIcon: Icon(Icons.palette_outlined),
                      hintText: '#FF9EAA',
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _secondaryHexController,
                    decoration: const InputDecoration(
                      labelText: 'Secondary Color',
                      prefixIcon: Icon(Icons.palette_outlined),
                      hintText: '#B0D9B1',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Dark Mode Settings', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                Switch(
                  value: themeProvider.isDarkMode,
                  onChanged: (val) => themeProvider.toggleDarkMode(val),
                ),
              ],
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _applyCustomTheme,
              child: const Text('Apply Colors'),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 3. 2FA Security Configuration Sub-Screen
// ==========================================
class TwoFactorSetupSubScreen extends StatefulWidget {
  const TwoFactorSetupSubScreen({super.key});

  @override
  State<TwoFactorSetupSubScreen> createState() => _TwoFactorSetupSubScreenState();
}

class _TwoFactorSetupSubScreenState extends State<TwoFactorSetupSubScreen> {
  final _verificationController = TextEditingController();
  String? _generatedSecret;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.currentUser;

    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(
        title: const Text('2FA Security Setup'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: user.isTotpEnabled
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  const Center(
                    child: Icon(Icons.shield_rounded, size: 72, color: Colors.green),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Two-Factor Authentication is Active',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your login is securely guarded by Google Authenticator app time steps.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5)),
                  ),
                  const SizedBox(height: 48),
                  ElevatedButton(
                    onPressed: () async {
                      await auth.disableTotp();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Two-factor authentication disabled.'),
                          backgroundColor: Colors.blueGrey,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade700),
                    child: const Text('Deactivate Two-Factor (2FA)'),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Multi-Factor Authentication (MFA)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Two-Factor Authentication adds an extra layer of protection by requiring a 6-digit verification code from your Google Authenticator or similar TOTP app at login.',
                    style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withOpacity(0.6), height: 1.4),
                  ),
                  const SizedBox(height: 24),
                  if (_generatedSecret == null) ...[
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _generatedSecret = auth.generateTotpSecret();
                        });
                      },
                      icon: const Icon(Icons.vpn_key_outlined),
                      label: const Text('Generate 2FA Secret Key'),
                    ),
                  ] else ...[
                    Center(
                      child: QrImageView(
                        data: 'otpauth://totp/BabyShopHub:${Uri.encodeComponent(auth.currentUser?.email ?? 'User')}?secret=$_generatedSecret&issuer=BabyShopHub',
                        version: QrVersions.auto,
                        size: 200.0,
                        backgroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final uri = Uri.parse('otpauth://totp/BabyShopHub:${Uri.encodeComponent(auth.currentUser?.email ?? 'User')}?secret=$_generatedSecret&issuer=BabyShopHub');
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri);
                        } else {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Could not open authenticator app automatically.')),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.open_in_new_rounded),
                      label: const Text('Open in Authenticator App'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                        foregroundColor: theme.colorScheme.primary,
                        elevation: 0,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Enter Verification OTP Code',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _verificationController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      decoration: const InputDecoration(
                        labelText: '6-Digit TOTP Code',
                        hintText: 'e.g. 123456',
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () async {
                        final code = _verificationController.text.trim();
                        final success = await auth.enableTotp(_generatedSecret!, code);
                        if (!mounted) return;
                        if (success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Two-factor authentication activated!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                          setState(() {
                            _generatedSecret = null;
                            _verificationController.clear();
                          });
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Verification failed. Check the app clocks and try again.'),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                        }
                      },
                      child: const Text('Verify and Activate'),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

// ==========================================
// 4. About Us Sub-Screen
// ==========================================
class AboutUsSubScreen extends StatelessWidget {
  const AboutUsSubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('About BabyShopHub'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(
              child: Icon(Icons.health_and_safety_outlined, size: 72, color: Colors.blueAccent),
            ),
            const SizedBox(height: 20),
            const Text(
              'Premium Standards in Infant Care',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'BabyShopHub is dedicated to offering only clinically certified, pediatric-tested baby essentials. We understand the paramount importance of clinical safety, non-toxic products, and comfort during your child’s critical developmental milestones.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface.withOpacity(0.7), height: 1.5),
            ),
            const SizedBox(height: 32),
            _buildAboutRow(
              context,
              icon: Icons.eco_outlined,
              title: '100% Organic Products',
              description: 'We prioritize sustainably farmed fabrics and completely organic baby formulas containing zero synthetic fillers.',
            ),
            _buildAboutRow(
              context,
              icon: Icons.verified_outlined,
              title: 'Clinical Certifications',
              description: 'Every product batch undergoes strict dermatological screening to avoid infant skin irritation and allergies.',
            ),
            _buildAboutRow(
              context,
              icon: Icons.assignment_return_outlined,
              title: '30-Day Hassle-Free Returns',
              description: 'Our customer care handles swift exchanges on unopened shipments, ensuring absolute satisfaction.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutRow(BuildContext context, {required IconData icon, required String title, required String description}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 28, color: theme.colorScheme.primary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withOpacity(0.6), height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 5. Contact Us Sub-Screen
// ==========================================
class ContactUsSubScreen extends StatefulWidget {
  const ContactUsSubScreen({super.key});

  @override
  State<ContactUsSubScreen> createState() => _ContactUsSubScreenState();
}

class _ContactUsSubScreenState extends State<ContactUsSubScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    _nameController.text = auth.currentUser?.displayName ?? '';
    _emailController.text = auth.currentUser?.email ?? '';
  }

  Future<void> _submitMessage() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;

      // 1. Create a support ticket in support_tickets collection for the admin panel inbox
      await FirebaseFirestore.instance.collection('support_tickets').add({
        'userId': user?.uid ?? '',
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'subject': _subjectController.text.trim(),
        'message': _messageController.text.trim(),
        'status': 'Open',
        'replies': [],
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 2. Register Support SMTP ticket document
      await FirebaseFirestore.instance.collection('mail_triggers').add({
        'to': 'no-reply@theali.app',
        'type': 'SUPPORT_CONTACT',
        'data': {
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'subject': _subjectController.text.trim(),
          'message': _messageController.text.trim(),
        },
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Support request sent successfully.'),
          backgroundColor: Colors.green,
        ),
      );

      _subjectController.clear();
      _messageController.clear();
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contact Customer Support'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Direct Message Routing',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Your Name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Enter email address';
                  final reg = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                  if (!reg.hasMatch(val)) return 'Enter valid email address';
                  return null;
                },
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _subjectController,
                validator: (val) => val == null || val.trim().isEmpty ? 'Enter subject' : null,
                decoration: const InputDecoration(
                  labelText: 'Inquiry Subject',
                  prefixIcon: Icon(Icons.subject_rounded),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _messageController,
                maxLines: 5,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Enter message';
                  if (val.trim().length < 10) return 'Message must be at least 10 characters';
                  return null;
                },
                decoration: const InputDecoration(
                  labelText: 'Support Message Details',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submitMessage,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Send Support Request'),
              ),
              const SizedBox(height: 32),
              Center(
                child: Text(
                  'Or contact us directly at:',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  'no-reply@theali.app\n+1 (234) 567-890',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
