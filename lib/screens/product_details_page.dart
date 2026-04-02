import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';

import '../models/product.dart';
import '../services/chat_service.dart';
import '../config/constants.dart';

/// صفحة تفاصيل المنتج
class ProductDetailsPage extends StatelessWidget {
  final Product product;
  final List<Product> allProducts;

  const ProductDetailsPage({
    super.key,
    required this.product,
    required this.allProducts,
  });

  @override
  Widget build(BuildContext context) {
    // جلب المنتجات ذات الصلة بناءً على القسم (Category) باستثناء المنتج الحالي
    final relatedProducts = allProducts
        .where((p) => p.category == product.category && p.name != product.name)
        .take(AppConstants.maxRelatedProducts)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل المنتج'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.brown,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.share),
            tooltip: 'خيارات المشاركة',
            onSelected: (value) async {
              final productUrl =
                  '${AppConstants.baseUrl}${AppConstants.productUrl(product.name.hashCode.abs())}';
              if (value == 'share') {
                SharePlus.instance.share(
                  ShareParams(text: 'شوف المنتج ده على شياكة : $productUrl'),
                );
              } else if (value == 'copy') {
                await Clipboard.setData(ClipboardData(text: productUrl));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم نسخ الرابط للحافظة بنجاح!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'share',
                child: Row(
                  children: [
                    Icon(Icons.share, color: Colors.brown, size: 20),
                    SizedBox(width: 8),
                    Text('مشاركة عبر التطبيقات'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'copy',
                child: Row(
                  children: [
                    Icon(Icons.copy, color: Colors.brown, size: 20),
                    SizedBox(width: 8),
                    Text('نسخ الرابط'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // صورة المنتج الكبيرة
            Container(
              width: double.infinity,
              height: 400,
              color: Colors.white,
              child: Hero(
                tag: 'image_${product.name}',
                child: CachedNetworkImage(
                  imageUrl: product.imageUrl.isNotEmpty
                      ? product.imageUrl
                      : 'https://via.placeholder.com/400',
                  fit: BoxFit.contain,
                  placeholder: (context, url) => const Center(
                    child: CircularProgressIndicator(color: Colors.brown),
                  ),
                  errorWidget: (context, url, error) => const Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: Colors.grey,
                      size: 60,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // تفاصيل المنتج
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (product.category != 'أخرى')
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.brown[50],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        product.category,
                        style: TextStyle(
                          color: Colors.brown[800],
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (product.price.isNotEmpty &&
                          product.price != 'Price not found')
                        Text(
                          '${product.price} جنيه',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[800],
                          ),
                        ),
                      const SizedBox(width: 16),
                      if (product.discount.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            product.discount,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      const Spacer(),
                      if (product.rating.isNotEmpty &&
                          product.rating != 'Rating not found')
                        Row(
                          children: [
                            const Icon(
                              Icons.star,
                              color: Colors.amber,
                              size: 20,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              product.rating,
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'وصف المنتج',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    product.description.isNotEmpty
                        ? product.description
                        : 'لا يوجد وصف متاح لهذا المنتج حالياً.',
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.6,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 32),
                  if (relatedProducts.isNotEmpty) ...[
                    const Text(
                      'منتجات ذات صلة',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 200,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: relatedProducts.length,
                        itemBuilder: (context, index) {
                          final relProduct = relatedProducts[index];
                          return Container(
                            width: 160,
                            margin: const EdgeInsets.only(right: 16, bottom: 8),
                            child: GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    settings: RouteSettings(
                                      name:
                                          '/product/${relProduct.name.hashCode.abs()}',
                                    ),
                                    builder: (context) => ProductDetailsPage(
                                      product: relProduct,
                                      allProducts: allProducts,
                                    ),
                                  ),
                                );
                              },
                              child: Card(
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius:
                                            const BorderRadius.vertical(
                                              top: Radius.circular(15),
                                            ),
                                        child: Hero(
                                          tag: 'image_${relProduct.name}',
                                          child: CachedNetworkImage(
                                            imageUrl: relProduct.imageUrl,
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                            placeholder: (context, url) =>
                                                const Center(
                                                  child: SizedBox(
                                                    width: 20,
                                                    height: 20,
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                          color: Colors.brown,
                                                        ),
                                                  ),
                                                ),
                                            errorWidget:
                                                (
                                                  context,
                                                  url,
                                                  error,
                                                ) => const Center(
                                                  child: Icon(
                                                    Icons.broken_image_outlined,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Text(
                                        relProduct.name,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        left: 8.0,
                                        right: 8.0,
                                        bottom: 8.0,
                                      ),
                                      child: Text(
                                        '${relProduct.price} جنيه',
                                        style: TextStyle(
                                          color: Colors.green[800],
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () => launchUrl(Uri.parse(product.link)),
                    icon: const Icon(Icons.shopping_cart),
                    label: const Text(
                      'اشتري الآن',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.brown,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      elevation: 4,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await ChatService.openWhatsApp(product.name);
                    },
                    icon: const Icon(Icons.chat, size: 22),
                    label: const Text(
                      'واتساب',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[600],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      elevation: 4,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}