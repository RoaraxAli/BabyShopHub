import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CloudinaryService {
  static const String _cloudNameKey = 'cloudinary_cloud_name';
  static const String _presetKey = 'cloudinary_upload_preset';

  // Default fallback credentials
  static const String defaultCloudName = 'dbbdbdetc';
  static const String defaultUploadPreset = 'meowmeow';

  String _cloudName = defaultCloudName;
  String _uploadPreset = defaultUploadPreset;

  String get cloudName => _cloudName;
  String get uploadPreset => _uploadPreset;

  // Initialize service by loading keys from preferences
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _cloudName = prefs.getString(_cloudNameKey) ?? defaultCloudName;
      _uploadPreset = prefs.getString(_presetKey) ?? defaultUploadPreset;
    } catch (e) {
      debugPrint('[CLOUDINARY SERVICE] Initialization error: $e');
    }
  }

  // Update credentials and persist them
  Future<void> updateCredentials(String newCloudName, String newPreset) async {
    _cloudName = newCloudName.trim();
    _uploadPreset = newPreset.trim();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cloudNameKey, _cloudName);
      await prefs.setString(_presetKey, _uploadPreset);
    } catch (e) {
      debugPrint('[CLOUDINARY SERVICE] Failed to save credentials: $e');
    }
  }

  // Upload an image to Cloudinary using multipart request
  Future<String?> uploadImage(XFile imageFile) async {
    if (_cloudName.isEmpty || _uploadPreset.isEmpty) {
      debugPrint('[CLOUDINARY SERVICE] Missing Cloudinary settings.');
      return null;
    }

    final url = Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/image/upload');
    
    try {
      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = _uploadPreset;

      // Handle both mobile (file path) and web/desktop (bytes)
      if (kIsWeb) {
        final bytes = await imageFile.readAsBytes();
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: imageFile.name,
          ),
        );
      } else {
        request.files.add(
          await http.MultipartFile.fromPath(
            'file',
            imageFile.path,
          ),
        );
      }

      final response = await request.send();
      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = await response.stream.bytesToString();
        final Map<String, dynamic> jsonResponse = json.decode(responseData);
        final secureUrl = jsonResponse['secure_url'] as String?;
        debugPrint('[CLOUDINARY SERVICE] Upload success: $secureUrl');
        return secureUrl;
      } else {
        final responseData = await response.stream.bytesToString();
        debugPrint('[CLOUDINARY SERVICE] Upload failed with code ${response.statusCode}: $responseData');
        return null;
      }
    } catch (e) {
      debugPrint('[CLOUDINARY SERVICE] Exception during upload: $e');
      return null;
    }
  }
}
