import 'constants.dart';

/// إعدادات التطبيق - واجهة موحدة للوصول إلى الثوابت
/// يمكن استخدام هذه الفئة كـ Facade لـ AppConstants
class AppConfig {
  // تفويض جميع الثوابت إلى AppConstants
  static String get productsCsvUrl => AppConstants.productsCsvUrl;
  static String get reviewsApiUrl => AppConstants.reviewsApiUrl;
  static String get whatsappNumber => AppConstants.whatsappNumber;
  static String get baseUrl => AppConstants.baseUrl;
  
  /// دوال مساعدة
  static String whatsappMessage(String productName) => 
      AppConstants.whatsappMessage(productName);
  static String productUrl(int productHash) => 
      AppConstants.productUrl(productHash);
}
