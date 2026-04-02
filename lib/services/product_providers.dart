import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/product.dart';
import '../services/data_service.dart';

// ============================================================================
// Data Layer Providers
// ============================================================================

/// Provider لتوفير نسخة (Instance) من الـ DataService
final dataServiceProvider = Provider<DataService>((ref) {
  return DataService();
});

/// FutureProvider لجلب المنتجات (وتخزينها تلقائياً في الذاكرة Caching)
final productsProvider = FutureProvider<List<Product>>((ref) async {
  final dataService = ref.read(dataServiceProvider);
  return dataService.fetchProducts();
});

// ============================================================================
// UI State Providers (الفلاتر والبحث)
// ============================================================================

/// حالة بحث النص
final searchQueryProvider = StateProvider<String>((ref) => '');

/// حالة الفئة المحددة
final selectedCategoryProvider = StateProvider<String>((ref) => 'الكل');

/// حالة ترتيب المنتجات
final sortOrderProvider = StateProvider<String>((ref) => 'الافتراضي');

// ============================================================================
// Filtered Products Provider (المنطق المركزي للفلترة)
// ============================================================================

/// Provider يقوم بفلترة وترتيب المنتجات بناءً على حالة الفلاتر
/// هذا يحول المنطق من UI إلى Layer منفصل
final filteredProductsProvider = Provider<List<Product>>((ref) {
  final productsAsync = ref.watch(productsProvider);
  final searchQuery = ref.watch(searchQueryProvider);
  final selectedCategory = ref.watch(selectedCategoryProvider);
  final sortOrder = ref.watch(sortOrderProvider);

  return productsAsync.when(
    data: (allProducts) {
      // فلترة البحث
      var filtered = allProducts.where((product) {
        final matchesSearch = searchQuery.isEmpty ||
            product.name.toLowerCase().contains(searchQuery.toLowerCase());
        final matchesCategory = selectedCategory == 'الكل' ||
            product.category == selectedCategory;
        return matchesSearch && matchesCategory;
      }).toList();

      // ترتيب حسب السعر
      if (sortOrder == 'الأقل سعراً') {
        filtered.sort((a, b) => _parsePrice(a.price).compareTo(_parsePrice(b.price)));
      } else if (sortOrder == 'الأعلى سعراً') {
        filtered.sort((a, b) => _parsePrice(b.price).compareTo(_parsePrice(a.price)));
      }

      return filtered;
    },
    loading: () => [],
    error: (_, _) => [],
  );
});

/// دالة مساعدة لتحليل السعر
double _parsePrice(String priceString) {
  if (priceString.isEmpty) return 0.0;
  final price = priceString.replaceAll(RegExp(r'[^\d.]'), '');
  return double.tryParse(price) ?? 0.0;
}

// ============================================================================
// Categories Provider (استخراج الفئات تلقائياً)
// ============================================================================

/// Provider يستخرج قائمة الفئات من المنتجات
final categoriesProvider = Provider<List<String>>((ref) {
  final productsAsync = ref.watch(productsProvider);

  return productsAsync.when(
    data: (products) {
      final categories = ['الكل'];
      categories.addAll(
        products
            .map((p) => p.category)
            .toSet()
            .where((c) => c != 'أخرى'),
      );
      if (products.any((p) => p.category == 'أخرى')) {
        categories.add('أخرى');
      }
      return categories;
    },
    loading: () => ['الكل'],
    error: (_, _) => ['الكل'],
  );
});

// ============================================================================
// Review/Comment Providers
// ============================================================================

/// حالة نص التعليق الحالي
final commentTextProvider = StateProvider.family<String, String>((ref, productName) => '');

/// حالة التقييم (عدد النجوم) لمنتج معين
final ratingValueProvider = StateProvider.family<double, String>((ref, productName) => 0.0);

/// حالة إرسال التعليق (loading/error/success)
final isSubmittingCommentProvider = StateProvider.family<bool, String>((ref, productName) => false);
