import 'package:url_launcher/url_launcher.dart';
import '../config/constants.dart';

/// خدمة التواصل عبر واتساب
/// مسؤولة عن تحضير الروابط وفتح المحادثات
class ChatService {
  /// الحصول على رابط واتساب لمنتج معين
  /// [productName] اسم المنتج للاستفسار عنه
  static String getWhatsAppUrl(String productName) {
    // تشفير الرسالة لدعم الأحرف العربية بشكل صحيح
    final message = Uri.encodeComponent(
      AppConstants.whatsappMessage(productName),
    );
    
    return 'https://wa.me/${AppConstants.whatsappNumber}?text=$message';
  }

  /// فتح محادثة واتساب لمنتج معين
  /// [productName] اسم المنتج للاستفسار عنه
  static Future<bool> openWhatsApp(String productName) async {
    final url = Uri.parse(getWhatsAppUrl(productName));
    
    if (await canLaunchUrl(url)) {
      return await launchUrl(
        url,
        mode: LaunchMode.externalApplication, // فتح في تطبيق واتساب الخارجي
      );
    }
    
    return false;
  }

  /// فتح واتساب مع رسالة مخصصة
  /// [phoneNumber] رقم الهاتف (بدون +)
  /// [message] نص الرسالة
  static Future<bool> openWhatsAppCustom({
    required String phoneNumber,
    required String message,
  }) async {
    final encodedMessage = Uri.encodeComponent(message);
    final url = Uri.parse('https://wa.me/$phoneNumber?text=$encodedMessage');
    
    if (await canLaunchUrl(url)) {
      return await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );
    }
    
    return false;
  }

  /// التحقق من إمكانية فتح واتساب
  static Future<bool> canOpenWhatsApp() async {
    final url = Uri.parse('https://wa.me/${AppConstants.whatsappNumber}');
    return await canLaunchUrl(url);
  }
}