import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/auth_provider.dart';
import '../models/user.dart';

class SavedAddressesScreen extends StatelessWidget {
  const SavedAddressesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = Provider.of<AuthProvider>(context);
    final addresses = auth.currentUser?.addresses ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Addresses'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddressForm(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Address'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: addresses.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.location_off_rounded, size: 64, color: theme.colorScheme.onSurface.withOpacity(0.2)),
                  const SizedBox(height: 16),
                  Text(
                    'No saved addresses yet',
                    style: TextStyle(fontSize: 16, color: theme.colorScheme.onSurface.withOpacity(0.4)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add a delivery address to speed up checkout',
                    style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withOpacity(0.3)),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: addresses.length,
              itemBuilder: (context, index) {
                final addr = addresses[index];
                return _buildAddressCard(context, addr, theme);
              },
            ),
    );
  }

  Widget _buildAddressCard(BuildContext context, UserAddress addr, ThemeData theme) {
    final auth = Provider.of<AuthProvider>(context, listen: false);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: addr.isDefault
            ? BorderSide(color: theme.colorScheme.primary, width: 1.5)
            : BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on_rounded, color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  addr.title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                if (addr.isDefault) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Default',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                    ),
                  ),
                ],
                const Spacer(),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, size: 20),
                  onSelected: (val) async {
                    if (val == 'edit') {
                      _showAddressForm(context, address: addr);
                    } else if (val == 'delete') {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          title: const Text('Delete Address'),
                          content: Text('Are you sure you want to delete "${addr.title}"?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                            ElevatedButton(
                              onPressed: () => Navigator.of(ctx).pop(true),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        await auth.deleteAddress(addr.id);
                      }
                    } else if (val == 'default') {
                      await auth.setDefaultAddress(addr.id);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    if (!addr.isDefault)
                      const PopupMenuItem(value: 'default', child: Text('Set as Default')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.redAccent))),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              addr.recipientName,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              '${addr.addressLine1}${addr.addressLine2 != null && addr.addressLine2!.isNotEmpty ? ', ${addr.addressLine2}' : ''}',
              style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withOpacity(0.6)),
            ),
            Text(
              '${addr.city}, ${addr.postalCode}',
              style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withOpacity(0.6)),
            ),
            const SizedBox(height: 4),
            Text(
              addr.phone,
              style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withOpacity(0.5)),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddressForm(BuildContext context, {UserAddress? address}) {
    final formKey = GlobalKey<FormState>();
    final titleCtrl = TextEditingController(text: address?.title ?? '');
    final nameCtrl = TextEditingController(text: address?.recipientName ?? '');
    final phoneCtrl = TextEditingController(text: address?.phone ?? '');
    final line1Ctrl = TextEditingController(text: address?.addressLine1 ?? '');
    final line2Ctrl = TextEditingController(text: address?.addressLine2 ?? '');
    final cityCtrl = TextEditingController(text: address?.city ?? '');
    final postalCtrl = TextEditingController(text: address?.postalCode ?? '');
    bool isDefault = address?.isDefault ?? false;
    final isNew = address == null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(isNew ? 'Add New Address' : 'Edit Address', style: const TextStyle(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 420,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(labelText: 'Label (e.g., Home, Work)', prefixIcon: Icon(Icons.label_outline)),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Recipient Name', prefixIcon: Icon(Icons.person_outline)),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-() ]'))],
                      decoration: const InputDecoration(labelText: 'Phone Number', prefixIcon: Icon(Icons.phone_outlined)),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        if (v.trim().length < 7) return 'Invalid phone number';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: line1Ctrl,
                      decoration: const InputDecoration(labelText: 'Address Line 1', prefixIcon: Icon(Icons.home_outlined)),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: line2Ctrl,
                      decoration: const InputDecoration(labelText: 'Address Line 2 (Optional)', prefixIcon: Icon(Icons.location_on_outlined)),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: cityCtrl,
                            decoration: const InputDecoration(labelText: 'City', prefixIcon: Icon(Icons.location_city_outlined)),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: postalCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Postal Code', prefixIcon: Icon(Icons.pin_outlined)),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      value: isDefault,
                      onChanged: (v) => setDialogState(() => isDefault = v ?? false),
                      title: const Text('Set as default address', style: TextStyle(fontSize: 13)),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            ElevatedButton.icon(
              icon: Icon(isNew ? Icons.add : Icons.save_rounded, size: 16),
              label: Text(isNew ? 'Add Address' : 'Save Changes'),
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final auth = Provider.of<AuthProvider>(context, listen: false);
                if (isNew) {
                  await auth.addAddress(
                    title: titleCtrl.text.trim(),
                    recipientName: nameCtrl.text.trim(),
                    phone: phoneCtrl.text.trim(),
                    addressLine1: line1Ctrl.text.trim(),
                    addressLine2: line2Ctrl.text.trim(),
                    city: cityCtrl.text.trim(),
                    postalCode: postalCtrl.text.trim(),
                    isDefault: isDefault,
                  );
                } else {
                  await auth.updateAddress(
                    addressId: address.id,
                    title: titleCtrl.text.trim(),
                    recipientName: nameCtrl.text.trim(),
                    phone: phoneCtrl.text.trim(),
                    addressLine1: line1Ctrl.text.trim(),
                    addressLine2: line2Ctrl.text.trim(),
                    city: cityCtrl.text.trim(),
                    postalCode: postalCtrl.text.trim(),
                    isDefault: isDefault,
                  );
                }
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}
