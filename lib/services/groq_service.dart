import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class GroqService {
  static const String _apiKey =
      String.fromEnvironment('GROQ_API_KEY', defaultValue: '');
  static const String _baseUrl =
      'https://api.groq.com/openai/v1/chat/completions';

  // List of models in order of preference (best first)
  List<String> get _models => const [
    'llama-3.3-70b-versatile',
    'llama-3.1-8b-instant',
  ];

  // System instructions to guide the bot's tone and context
  static const String _systemPrompt =
      "You are BabyShopHub's helpful AI customer support agent. "
      "You assist parents with baby product recommendations, safety questions, shipping details, or return policies. "
      "Your tone should be warm, clinical, and reassuring. Keep answers concise and helpful.";

  /// Sends a list of chat messages to Groq using model fallback logic
  Future<String> getChatResponse(
    List<Map<String, String>> conversationHistory,
  ) async {
    // Inject system prompt at start
    final messages = [
      {'role': 'system', 'content': _systemPrompt},
      ...conversationHistory,
    ];

    // Try models one by one in case of failure/rate limit
    for (String model in _models) {
      debugPrint('[GROQ SERVICE] Attempting chat request with model: $model');
      try {
        final response = await http
            .post(
              Uri.parse(_baseUrl),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $_apiKey',
              },
              body: jsonEncode({
                'model': model,
                'messages': messages,
                'temperature': 0.7,
                'max_tokens': 1024,
              }),
            )
            .timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final String reply = data['choices'][0]['message']['content'] ?? '';
          if (reply.isNotEmpty) {
            debugPrint('[GROQ SERVICE] Success using model: $model');
            return reply;
          }
        } else {
          debugPrint(
            '[GROQ SERVICE] Error from Groq ($model): ${response.statusCode} - ${response.body}',
          );
        }
      } catch (e) {
        debugPrint('[GROQ SERVICE] Exception using model $model: $e');
      }
    }

    return _getOfflineResponse(conversationHistory);
  }

  String _getOfflineResponse(List<Map<String, String>> conversationHistory) {
    final userMessages = conversationHistory
        .where((message) => message['role'] == 'user')
        .map((message) => message['content'] ?? '')
        .where((message) => message.trim().isNotEmpty)
        .toList();
    final latestMessage = userMessages.isEmpty
        ? ''
        : userMessages.last.toLowerCase();

    if (latestMessage.contains('diaper') || latestMessage.contains('nappy')) {
      return 'For diapers, choose by your baby\'s current weight first, then look for a soft waistband, wetness indicator, and good overnight absorbency. If your baby has sensitive skin, fragrance-free diapers are the safest first pick.';
    }

    if (latestMessage.contains('food') ||
        latestMessage.contains('formula') ||
        latestMessage.contains('organic')) {
      return 'For baby food, check the age label, ingredient list, and allergen notes. Organic options can be a nice choice, but the most important things are age-appropriate texture, no added sugar, and safe storage after opening.';
    }

    if (latestMessage.contains('return') || latestMessage.contains('refund')) {
      return 'For returns, keep the item sealed and save your order details. Baby care products are usually easiest to return when unopened, unused, and still in their original packaging.';
    }

    if (latestMessage.contains('ship') || latestMessage.contains('delivery')) {
      return 'Shipping depends on your address and order size. For faster delivery, place essentials like diapers, wipes, formula, and clothing in one order so everything arrives together.';
    }

    if (latestMessage.contains('toy') || latestMessage.contains('safe')) {
      return 'For toys, choose age-rated items with no small detachable parts, soft edges, and washable materials. For babies under 12 months, simple sensory toys and soft plush items are usually best.';
    }

    return 'I can help with product recommendations, diapers, baby food, toys, shipping, and returns. Tell me your baby\'s age or what you need, and I\'ll suggest a safe option.';
  }
}
