import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';

import '../models/product.dart';
import '../services/data_service.dart';
import '../config/app_config.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  late Future<List<Product>> productsFuture;
  String _searchQuery = '';
  String _selectedCategory = 'الكل';
  String _sortOrder = 'الافتراضي';

  @override
  void initState() {
    super.initState();
    final dataService = DataService();
    productsFuture = dataService.fetchProducts();
  }

  double _parsePrice(String priceString) {
    if (priceString.isEmpty) return 0.0;
    final price = priceString.replaceAll(RegExp(r'[^\d.]'), '');
    return double.tryParse(price) ?? 0.0;
  }

  Widget _buildPromoBanners() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        children: [
          Container(
            height: 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              gradient: const LinearGradient(
                colors: [Colors.brown, Colors.orange],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: const Center(
              child: Text(
                'عروض خاصة هذا الأسبوع!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            height: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              color: Colors.grey[200],
            ),
            child: const Center(
              child: Text(
                'شحن مجاني لجميع الطلبات فوق 500 جنيه',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Placeholder لعرض Shimmer Effect أثناء التحميل
  Widget _buildProductCardPlaceholder() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // محاكاة صورة المنتج
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  // محاكاة عنوان المنتج
                  Container(
                    width: double.infinity,
                    height: 14,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 8),
                  Container(width: 120, height: 14, color: Colors.white),
                  const SizedBox(height: 12),
                  // محاكاة السعر
                  Container(width: 80, height: 18, color: Colors.white),
                  const SizedBox(height: 16),
                  // محاكاة أزرار الشراء والمشاركة
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // تحديد عدد الأعمدة ونسبة العرض إلى الارتفاع بناءً على حجم الشاشة لتجاوب أفضل
        int crossAxisCount;
        double childAspectRatio;

        if (constraints.maxWidth > 1200) {
          crossAxisCount = 5;
          childAspectRatio = 0.48;
        } else if (constraints.maxWidth > 800) {
          crossAxisCount = 4;
          childAspectRatio = 0.48;
        } else if (constraints.maxWidth > 600) {
          crossAxisCount = 3;
          childAspectRatio = 0.48;
        } else if (constraints.maxWidth > 450) {
          crossAxisCount = 2;
          childAspectRatio = 0.45; // للتابلت والشاشات المتوسطة
        } else {
          crossAxisCount = 1;
          childAspectRatio =
              0.75; // ممتاز للجوال (عمود واحد بمساحة أفقية كاملة)
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'شياكة بيت ✨',
              style: TextStyle(
                color: Colors.brown,
                fontWeight: FontWeight.bold,
              ),
            ),
            centerTitle: true,
            backgroundColor: Colors.white,
            elevation: 0,
            actions: [
              PopupMenuButton<String>(
                icon: const Icon(Icons.sort, color: Colors.brown),
                tooltip: 'ترتيب المنتجات',
                onSelected: (value) {
                  setState(() {
                    _sortOrder = value;
                  });
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'الافتراضي',
                    child: Text('الترتيب الافتراضي'),
                  ),
                  const PopupMenuItem(
                    value: 'الأقل سعراً',
                    child: Text('الأقل سعراً'),
                  ),
                  const PopupMenuItem(
                    value: 'الأعلى سعراً',
                    child: Text('الأعلى سعراً'),
                  ),
                ],
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: FutureBuilder<List<Product>>(
            future: productsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                // استخدام نفس الـ LayoutBuilder لضبط الشيمر ليتطابق مع الشاشة
                return CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.all(16),
                      sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          childAspectRatio: childAspectRatio,
                          crossAxisSpacing: 15,
                          mainAxisSpacing: 15,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _buildProductCardPlaceholder(),
                          childCount: crossAxisCount * 3, // ملء الشاشة بالشيمر
                        ),
                      ),
                    ),
                  ],
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.wifi_off_outlined,
                        size: 60,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'حدث خطأ في الاتصال، تأكد من الإنترنت',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          final dataService = DataService();
                          setState(() {
                            productsFuture = dataService.fetchProducts();
                          });
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('إعادة المحاولة'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.brown,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                );
              }

              final allProducts = snapshot.data ?? [];

              final categories = ['الكل'];
              categories.addAll(
                allProducts
                    .map((p) => p.category)
                    .toSet()
                    .where((c) => c != 'أخرى'),
              );
              if (allProducts.any((p) => p.category == 'أخرى')) {
                categories.add('أخرى');
              }

              final filteredProducts = allProducts.where((product) {
                final matchesSearch =
                    _searchQuery.isEmpty ||
                    product.name.toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    );
                final matchesCategory =
                    _selectedCategory == 'الكل' ||
                    product.category == _selectedCategory;
                return matchesSearch && matchesCategory;
              }).toList();

              if (_sortOrder == 'الأقل سعراً') {
                filteredProducts.sort(
                  (a, b) =>
                      _parsePrice(a.price).compareTo(_parsePrice(b.price)),
                );
              } else if (_sortOrder == 'الأعلى سعراً') {
                filteredProducts.sort(
                  (a, b) =>
                      _parsePrice(b.price).compareTo(_parsePrice(a.price)),
                );
              }

              return RefreshIndicator(
                color: const Color.fromARGB(255, 83, 144, 235),
                onRefresh: () async {
                  final dataService = DataService();
                  final refreshedData = await dataService.fetchProducts();
                  setState(() {
                    productsFuture = Future.value(refreshedData);
                  });
                },
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Column(
                        children: [
                          const Padding(
                            padding: EdgeInsets.all(20.0),
                            child: Text(
                              "اختياراتنا لأفضل أدوات تنظيم المنزل العصرية",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w300,
                              ),
                            ),
                          ),
                          _buildPromoBanners(),
                          const SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24.0,
                              vertical: 8.0,
                            ),
                            child: TextField(
                              decoration: InputDecoration(
                                hintText: 'ابحث عن منتج...',
                                prefixIcon: const Icon(Icons.search),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15.0),
                                ),
                                filled: true,
                                fillColor: const Color.fromARGB(
                                  255,
                                  245,
                                  245,
                                  245,
                                ),
                              ),
                              onChanged: (value) {
                                setState(() {
                                  _searchQuery = value;
                                });
                              },
                            ),
                          ),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24.0,
                            ),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: categories.map((category) {
                                  return Padding(
                                    padding: const EdgeInsets.only(left: 8.0),
                                    child: ChoiceChip(
                                      label: Text(
                                        category,
                                        style: TextStyle(
                                          color: _selectedCategory == category
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                      ),
                                      selected: _selectedCategory == category,
                                      selectedColor: const Color.fromARGB(
                                        255,
                                        58,
                                        93,
                                        234,
                                      ),
                                      onSelected: (selected) {
                                        setState(() {
                                          _selectedCategory = category;
                                        });
                                      },
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                    if (filteredProducts.isEmpty)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.all(40.0),
                          child: Center(
                            child: Text(
                              'لم يتم العثور على منتجات مطابقة لبحثك.',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.all(16),
                        sliver: SliverGrid(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                childAspectRatio: childAspectRatio,
                                crossAxisSpacing: 15,
                                mainAxisSpacing: 15,
                              ),
                          delegate: SliverChildBuilderDelegate((context, index) {
                            final product = filteredProducts[index];
                            return GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    // عمل Named Route ليتغير رابط المتصفح بناءً على المنتج
                                    settings: RouteSettings(
                                      name:
                                          '/product/${product.name.hashCode.abs()}',
                                    ),
                                    builder: (context) => ProductDetailsPage(
                                      product: product,
                                      allProducts: allProducts,
                                    ),
                                  ),
                                );
                              },
                              child: ProductCard(
                                name: product.name,
                                imageUrl: product.imageUrl.isNotEmpty
                                    ? product.imageUrl
                                    : 'https://via.placeholder.com/300',
                                link: product.link,
                                rating: product.rating,
                                discount: product.discount,
                                price: product.price,
                                description: product.description,
                              ),
                            );
                          }, childCount: filteredProducts.length),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class ProductCard extends StatefulWidget {
  final String name;
  final String imageUrl;
  final String link;
  final String rating;
  final String discount;
  final String price;
  final String description;

  const ProductCard({
    super.key,
    required this.name,
    required this.imageUrl,
    required this.link,
    required this.rating,
    required this.discount,
    required this.price,
    required this.description,
  });

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  bool _isHovering = false;
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    if (_commentController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الرجاء إضافة تعليق قبل الإرسال'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final uri = Uri.parse(AppConfig.reviewsApiUrl).replace(queryParameters: {
        'productName': widget.name,
        'rating': '',
        'comment': _commentController.text,
      });
      await http.get(uri);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('شكراً لتقييمك!'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {
          _commentController.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        // Google Apps Script يقوم بعمل إعادة توجيه (Redirect) بعد الحفظ
        // مما يسبب أخطاء CORS بأسماء مختلفة في متصفحات الويب
        final errorStr = e.toString().toLowerCase();
        if (errorStr.contains('xmlhttprequest') ||
            errorStr.contains('fetch') ||
            errorStr.contains('clientexception')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('شكراً لتقييمك!'),
              backgroundColor: Colors.green,
            ),
          );
          setState(() {
            _commentController.clear();
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('الخطأ: $errorStr'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        transform: _isHovering
            ? Matrix4.translationValues(0.0, -8.0, 0.0)
            : Matrix4.identity(),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          boxShadow: _isHovering
              ? [
                  const BoxShadow(
                    color: Colors.black26,
                    blurRadius: 15,
                    offset: Offset(0, 8),
                  ),
                ]
              : [
                  const BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
        ),
        child: Card(
          elevation: 0, // الاعتماد على الـ Shadow الخاص بـ AnimatedContainer
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(15),
                      ),
                      child: Hero(
                        tag: 'image_${widget.name}',
                        child: CachedNetworkImage(
                          imageUrl: widget.imageUrl,
                          fit: BoxFit.contain,
                          placeholder: (context, url) => const Center(
                            child: CircularProgressIndicator(
                              color: Colors.brown,
                            ),
                          ),
                          errorWidget: (context, url, error) => const Center(
                            child: Icon(
                              Icons.broken_image_outlined,
                              color: Colors.grey,
                              size: 40,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // عرض علامة التخفيض
                    if (widget.discount.isNotEmpty)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            widget.discount,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  widget.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              // عرض الوصف المختصر
              if (widget.description.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8.0,
                    vertical: 2.0,
                  ),
                  child: Text(
                    widget.description,
                    maxLines:
                        3, // تم زيادة عدد الأسطر لعرض المنتجات الطويلة بشكل أفضل
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ),
              // عرض السعر
              if (widget.price.isNotEmpty && widget.price != 'Price not found')
                Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: Text(
                    '${widget.price} جنيه',
                    style: TextStyle(
                      color: Colors.green[800], // لون أخضر غامق لاحترافية أكثر
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              // عرض التقييم
              if (widget.rating.isNotEmpty &&
                  widget.rating != 'Rating not found')
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        widget.rating,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              // زر الشراء والمشاركة
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Material(
                        color: Colors.brown,
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () {
                            launchUrl(Uri.parse(widget.link));
                          },
                          splashColor: Colors.white.withValues(alpha: 0.3),
                          highlightColor: Colors.brown[700],
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            alignment: Alignment.center,
                            child: const Text(
                              "اشتري الآن",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.share, color: Colors.brown),
                      tooltip: 'خيارات المشاركة',
                      onSelected: (value) async {
                        final productUrl =
                            'https://mahmoudhan2025-o.github.io/sheyaka_bet/#/product/${widget.name.hashCode.abs()}';
                        if (value == 'share') {
                          SharePlus.instance.share(
                            ShareParams(
                              text: 'شوف المنتج ده على شياكة بيت: $productUrl',
                            ),
                          );
                        } else if (value == 'copy') {
                          await Clipboard.setData(
                            ClipboardData(text: productUrl),
                          );
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
              ),
              const SizedBox(height: 4),
              const Divider(height: 1, color: Colors.black12),
              Theme(
                data: Theme.of(
                  context,
                ).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  title: const Text(
                    'إضافة تعليق',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.brown,
                    ),
                  ),
                  tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                  childrenPadding: const EdgeInsets.only(
                    left: 12,
                    right: 12,
                    bottom: 12,
                  ),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _commentController,
                            decoration: InputDecoration(
                              hintText: 'أضف تعليقاً...',
                              hintStyle: const TextStyle(fontSize: 12),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: Colors.brown[200]!,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Colors.brown,
                                ),
                              ),
                            ),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _isSubmitting
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.brown,
                                ),
                              )
                            : IconButton(
                                icon: const Icon(
                                  Icons.send,
                                  color: Colors.brown,
                                  size: 24,
                                ),
                                onPressed: _submitReview,
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                                tooltip: 'إرسال',
                              ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
        .take(10) // عرض 10 منتجات كحد أقصى
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
                  'https://mahmoudhan2025-o.github.io/sheyaka_bet/#/product/${product.name.hashCode.abs()}';
              if (value == 'share') {
                SharePlus.instance.share(
                  ShareParams(text: 'شوف المنتج ده على شياكة بيت: $productUrl'),
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
                                    // تحديث الرابط أيضاً عند تصفح "منتجات ذات صلة"
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
          child: SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () => launchUrl(Uri.parse(product.link)),
              icon: const Icon(Icons.shopping_cart),
              label: const Text(
                'اشتري الآن',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.brown,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                elevation: 4, // لإضافة بروز خفيف للزر
              ),
            ),
          ),
        ),
      ),
    );
  }
}