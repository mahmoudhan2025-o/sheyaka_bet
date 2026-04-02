import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import '../models/product.dart';
import '../services/product_providers.dart';
import '../widgets/product_card.dart';
import 'product_details_page.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  // تم إزالة productsFuture لأننا سنستخدم Riverpod بدلاً منه

  @override
  Widget build(BuildContext context) {
    // مراقبة حالة المنتجات عبر Riverpod
    final productsAsync = ref.watch(productsProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        // تحديد عدد الأعمدة ونسبة العرض إلى الارتفاع بناءً على حجم الشاشة
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
          childAspectRatio = 0.45;
        } else {
          crossAxisCount = 1;
          childAspectRatio = 0.75;
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
              Consumer(
                builder: (context, ref, _) {
                  final sortOrder = ref.watch(sortOrderProvider);
                  return PopupMenuButton<String>(
                    initialValue: sortOrder,
                    icon: const Icon(Icons.sort, color: Colors.brown),
                    tooltip: 'ترتيب المنتجات',
                    onSelected: (value) {
                      ref.read(sortOrderProvider.notifier).state = value;
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
                  );
                },
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: productsAsync.when(
            // حالة التحميل
            loading: () => _buildLoadingState(crossAxisCount, childAspectRatio),

            // حالة الخطأ
            error: (error, stack) => _buildErrorState(error),

            // حالة النجاح (البيانات جاهزة)
            data: (allProducts) => _buildMainContent(
              allProducts,
              crossAxisCount,
              childAspectRatio,
            ),
          ),
        );
      },
    );
  }

  /// بناء واجهة التحميل مع Shimmer
  Widget _buildLoadingState(int crossAxisCount, double childAspectRatio) {
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
              childCount: crossAxisCount * 3,
            ),
          ),
        ),
      ],
    );
  }

  /// بناء واجهة الخطأ
  Widget _buildErrorState(dynamic error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off_outlined, size: 60, color: Colors.red),
          const SizedBox(height: 16),
          const Text(
            'حدث خطأ في الاتصال，تأكد من الإنترنت',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              ref.invalidate(productsProvider); // إعادة جلب البيانات
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

  /// بناء المحتوى الرئيسي بعد نجاح جلب البيانات
  Widget _buildMainContent(
    List<Product> allProducts,
    int crossAxisCount,
    double childAspectRatio,
  ) {
    // مراقبة المنتجات المفلترة والفئات عبر Riverpod
    final filteredProducts = ref.watch(filteredProductsProvider);
    final categories = ref.watch(categoriesProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);

    return RefreshIndicator(
      color: const Color.fromARGB(255, 83, 144, 235),
      onRefresh: () => ref.refresh(productsProvider.future),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Text(
                    "أهلا بكم في بيت الشياكة ",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w300),
                  ),
                ),
                _buildPromoBanners(),
                const SizedBox(height: 16),
                // حقل البحث
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
                      fillColor: const Color.fromARGB(255, 245, 245, 245),
                    ),
                    onChanged: (value) {
                      ref.read(searchQueryProvider.notifier).state = value;
                    },
                  ),
                ),
                // أزرار الفئات
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
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
                                color: selectedCategory == category
                                    ? Colors.white
                                    : Colors.black87,
                              ),
                            ),
                            selected: selectedCategory == category,
                            selectedColor: const Color.fromARGB(
                              255,
                              58,
                              93,
                              234,
                            ),
                            onSelected: (selected) {
                              ref
                                      .read(selectedCategoryProvider.notifier)
                                      .state =
                                  category;
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
          // عرض رسالة عند عدم وجود نتائج
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
            // عرض شبكة المنتجات
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
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
                          settings: RouteSettings(
                            name: '/product/${product.name.hashCode.abs()}',
                          ),
                          builder: (context) => ProductDetailsPage(
                            product: product,
                            allProducts: allProducts,
                          ),
                        ),
                      );
                    },
                    child: ProductCard(product: product),
                  );
                }, childCount: filteredProducts.length),
              ),
            ),
        ],
      ),
    );
  }
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
              'عروض خاصة !',
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
              'مع شياكة خلى بيتك شياكة',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
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
