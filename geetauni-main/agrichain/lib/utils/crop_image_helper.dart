import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CropImageHelper {
  /// Returns a high-resolution authentic farm photo based on crop name / keyword
  static String getContextualCropImageUrl(String cropName) {
    final name = cropName.toLowerCase().trim();

    if (name.contains('wheat') || name.contains('gehu') || name.contains('sharbati') || name.contains('flour') || name.contains('atta')) {
      return 'https://images.unsplash.com/photo-1574323347407-f5e1ad6d020b?w=800&auto=format&fit=crop&q=80';
    } else if (name.contains('rice') || name.contains('paddy') || name.contains('basmati') || name.contains('chawal') || name.contains('dhan')) {
      return 'https://images.unsplash.com/photo-1586201375761-83865001e31c?w=800&auto=format&fit=crop&q=80';
    } else if (name.contains('mustard') || name.contains('sarson') || name.contains('rai') || name.contains('oilseed')) {
      return 'https://images.unsplash.com/photo-1508747703725-719777637510?w=800&auto=format&fit=crop&q=80';
    } else if (name.contains('corn') || name.contains('maize') || name.contains('makka') || name.contains('bhutta')) {
      return 'https://images.unsplash.com/photo-1551754655-cd27e38d2076?w=800&auto=format&fit=crop&q=80';
    } else if (name.contains('cotton') || name.contains('kapas')) {
      return 'https://images.unsplash.com/photo-1605000797499-95a51c5269ae?w=800&auto=format&fit=crop&q=80';
    } else if (name.contains('sugarcane') || name.contains('ganna')) {
      return 'https://images.unsplash.com/photo-1527842891421-42eec6e703ea?w=800&auto=format&fit=crop&q=80';
    } else if (name.contains('soybean') || name.contains('soya')) {
      return 'https://images.unsplash.com/photo-1599420186946-7b6fb4e297f0?w=800&auto=format&fit=crop&q=80';
    } else if (name.contains('potato') || name.contains('aloo')) {
      return 'https://images.unsplash.com/photo-1518977676601-b53f82aba655?w=800&auto=format&fit=crop&q=80';
    } else if (name.contains('onion') || name.contains('pyaz')) {
      return 'https://images.unsplash.com/photo-1618512496248-a07fe83aa8cb?w=800&auto=format&fit=crop&q=80';
    } else if (name.contains('tomato') || name.contains('tamatar')) {
      return 'https://images.unsplash.com/photo-1592924357228-91a4daadcfea?w=800&auto=format&fit=crop&q=80';
    } else if (name.contains('pulse') || name.contains('dal') || name.contains('chana') || name.contains('gram') || name.contains('moong') || name.contains('urad') || name.contains('arhar')) {
      return 'https://images.unsplash.com/photo-1585992629285-a7b2bc21271f?w=800&auto=format&fit=crop&q=80';
    } else if (name.contains('vegetable') || name.contains('sabzi') || name.contains('chilli') || name.contains('garlic') || name.contains('ginger')) {
      return 'https://images.unsplash.com/photo-1540420773420-3366772f4999?w=800&auto=format&fit=crop&q=80';
    } else if (name.contains('mango') || name.contains('aam')) {
      return 'https://images.unsplash.com/photo-1553279768-865429fa0078?w=800&auto=format&fit=crop&q=80';
    } else if (name.contains('fruit') || name.contains('apple') || name.contains('banana') || name.contains('orange') || name.contains('guava')) {
      return 'https://images.unsplash.com/photo-1619566636858-adf3ef46400b?w=800&auto=format&fit=crop&q=80';
    }

    // Default pristine harvest image
    return 'https://images.unsplash.com/photo-1500937386664-56d1dfef3854?w=800&auto=format&fit=crop&q=80';
  }

  /// Builds a responsive crop image widget supporting base64, local files, network URLs, and contextual fallbacks.
  static Widget buildCropImage(
    String? imageUrl,
    String cropName, {
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    BorderRadius? borderRadius,
  }) {
    Widget imageWidget = _resolveImage(imageUrl, cropName, width, height, fit);

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius,
        child: imageWidget,
      );
    }
    return imageWidget;
  }

  static Widget _resolveImage(
    String? imageUrl,
    String cropName,
    double? width,
    double? height,
    BoxFit fit,
  ) {
    final String contextualUrl = getContextualCropImageUrl(cropName);

    if (imageUrl != null && imageUrl.trim().isNotEmpty) {
      final trimmed = imageUrl.trim();

      // Case 1: Base64 data URI or raw base64 string
      if (trimmed.startsWith('data:image') ||
          (trimmed.length > 80 &&
              !trimmed.startsWith('http') &&
              !trimmed.startsWith('assets/') &&
              !trimmed.startsWith('/') &&
              !trimmed.contains(':\\') &&
              !trimmed.contains(':/'))) {
        try {
          final cleanBase64 = trimmed.contains(',') ? trimmed.split(',').last : trimmed;
          final bytes = base64Decode(cleanBase64.replaceAll(RegExp(r'\s+'), ''));
          return Image.memory(
            bytes,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (_, __, ___) => _buildNetworkFallback(contextualUrl, width, height, fit),
          );
        } catch (e) {
          debugPrint('Error decoding crop image base64: $e');
        }
      }

      // Case 2: HTTP / HTTPS Network URL
      if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
        return Image.network(
          trimmed,
          width: width,
          height: height,
          fit: fit,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              width: width,
              height: height,
              color: AppTheme.lightGreen.withValues(alpha: 0.2),
              child: const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryGreen),
                ),
              ),
            );
          },
          errorBuilder: (_, __, ___) => _buildNetworkFallback(contextualUrl, width, height, fit),
        );
      }

      // Case 3: Local file on device
      if (!kIsWeb) {
        try {
          final cleanPath = trimmed.replaceFirst('file://', '');
          final file = File(cleanPath);
          if (file.existsSync()) {
            return Image.file(
              file,
              width: width,
              height: height,
              fit: fit,
              errorBuilder: (_, __, ___) => _buildNetworkFallback(contextualUrl, width, height, fit),
            );
          }
        } catch (e) {
          debugPrint('Error checking local image file: $e');
        }
      }
    }

    // Default fallback to contextual high-res agricultural image
    return _buildNetworkFallback(contextualUrl, width, height, fit);
  }

  static Widget _buildNetworkFallback(String url, double? width, double? height, BoxFit fit) {
    return Image.network(
      url,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, __, ___) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primaryGreen.withValues(alpha: 0.15),
              AppTheme.darkGreen.withValues(alpha: 0.25),
            ],
          ),
        ),
        child: const Center(
          child: Icon(Icons.eco, color: AppTheme.primaryGreen, size: 28),
        ),
      ),
    );
  }
}
