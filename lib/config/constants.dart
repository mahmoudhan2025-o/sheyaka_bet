import 'package:flutter_dotenv/flutter_dotenv.dart';

/// ثوابت التطبيق - جميع القيم الثابتة في مكان واحد
class AppConstants {
  // ============================================================================
  // API Endpoints
  // ============================================================================

  /// رابط جلب المنتجات من Google Sheets
  static String get productsCsvUrl => dotenv.env['PRODUCTS_CSV_URL'] ?? '';

  /// رابط إرسال التقييمات (Google Apps Script)
  static String get reviewsApiUrl => dotenv.env['REVIEWS_API_URL'] ?? '';

  // ============================================================================
  // WhatsApp
  // ============================================================================

  /// رقم واتساب للدعم
  static const String whatsappNumber = '201020406963';

  /// رسالة واتساب الافتراضية
  static String whatsappMessage(String productName) =>
      'أهلاً، أريد الاستفسار عن المنتج: $productName';

  // ============================================================================
  // URLs
  // ============================================================================

  /// الرابط الأساسي للتطبيق (GitHub Pages)
  static const String baseUrl =
      'https://mahmoudhan2025-o.github.io/sheyaka_bet/';

  /// رابط منتج معين
  static String productUrl(int productHash) => '#/product/$productHash';

  // ============================================================================
  // UI Constants
  // ============================================================================

  /// الألوان الأساسية
  static const int primaryColor = 0xFF795548; // Brown
  static const int accentColor = 0xFF4CAF50; // Green

  /// النصوص الثابتة
  static const String appName = 'شياكة بيت ✨';
  static const String appSlogan = 'مع القرش مش هيضيع منك قرش';
  static const String freeShippingText = 'شحن مجاني لجميع الطلبات فوق 500 جنيه';
  static const String specialOffersText = 'عروض خاصة !';

  // ============================================================================
  // Cache & Timeout
  // ============================================================================

  /// مهلة الاتصال بالثانية
  static const Duration connectionTimeout = Duration(seconds: 30);

  /// مهلة استلام البيانات
  static const Duration receiveTimeout = Duration(seconds: 30);

  // ============================================================================
  // Pagination
  // ============================================================================

  /// عدد المنتجات المعروضة في الصفحة الواحدة (للاستخدام المستقبلي)
  static const int productsPerPage = 20;

  /// الحد الأقصى للمنتجات ذات الصلة
  static const int maxRelatedProducts = 10;

  // ============================================================================
  // Validation
  // ============================================================================

  /// الحد الأدنى لطول التعليق
  static const int minCommentLength = 1;

  /// الحد الأقصى لطول التعليق
  static const int maxCommentLength = 500;

  /// الحد الأقصى للتقييم (عدد النجوم)
  static const int maxRating = 5;
}
