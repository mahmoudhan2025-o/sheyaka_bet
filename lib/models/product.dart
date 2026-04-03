class Product {
  final String name;
  final String imageUrl;
  final String link;
  final String rating;
  final String discount;
  final String category;
  final String price;
  final String description;
  final String productType; // نوع المنتج (أمازون، واتساب، الخ)

  Product({
    required this.name,
    required this.imageUrl,
    required this.link,
    this.rating = '',
    this.discount = '',
    this.category = 'أخرى',
    this.price = '',
    this.description = '',
  }) : productType = _determineType(link); // تحديد النوع تلقائياً من الرابط

  // دالة لتحديد نوع المنتج بناءً على الرابط الخاص به
  static String _determineType(String link) {
    final lowerLink = link.toLowerCase();
    if (lowerLink.contains('amazon') || lowerLink.contains('amzn.to')) {
      return 'amazon';
    } else if (lowerLink.contains('noon.com')) {
      return 'noon';
    } else if (lowerLink.contains('jumia.com')) {
      return 'jumia';
    } else if (lowerLink.contains('wa.me') || lowerLink.isEmpty) {
      return 'whatsapp'; // إذا لم يكن هناك رابط أو كان رابط واتساب، فهو منتج محلي
    }
    return 'external'; // رابط خارجي عام
  }
}
