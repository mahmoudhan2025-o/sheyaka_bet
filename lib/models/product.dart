class Product {
  final String name;
  final String imageUrl;
  final String link;
  final String rating;
  final String discount;
  final String category;
  final String price;
  final String description;

  Product({
    required this.name,
    required this.imageUrl,
    required this.link,
    this.rating = '',
    this.discount = '',
    this.category = 'أخرى',
    this.price = '',
    this.description = '',
  });
}
