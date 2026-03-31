import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/product.dart';
import '../services/data_service.dart';

// Provider لتوفير نسخة (Instance) من الـ DataService
final dataServiceProvider = Provider<DataService>((ref) {
  return DataService();
});

// FutureProvider لجلب المنتجات (وتخزينها تلقائياً في الذاكرة Caching)
final productsProvider = FutureProvider<List<Product>>((ref) async {
  final dataService = ref.read(dataServiceProvider);
  return dataService.fetchProducts();
});

// StateProviders لحفظ حالة فلاتر البحث والترتيب لتبقى محفوظة حتى لو تنقلنا بين الصفحات
final searchQueryProvider = StateProvider<String>((ref) => '');
final selectedCategoryProvider = StateProvider<String>((ref) => 'الكل');
final sortOrderProvider = StateProvider<String>((ref) => 'الافتراضي');