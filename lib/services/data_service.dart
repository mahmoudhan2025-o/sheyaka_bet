import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';
import '../models/product.dart';

class DataService {
  final String url = AppConfig.productsCsvUrl;

  Future<List<Product>> fetchProducts() async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final decodedBody = utf8.decode(response.bodyBytes);
        debugPrint('Data received: $decodedBody');

        final rows = const CsvToListConverter().convert(decodedBody);
        return rows
            .skip(1)
            .where((row) => row.isNotEmpty && row.length >= 4)
            .where(
              (row) =>
                  row.length > 1 && row[1].toString().trim().startsWith('http'),
            )
            .map(
              (row) => Product(
                name: row[0].toString(),
                imageUrl: row.length > 1 ? row[1].toString().trim() : '',
                link: row.length > 2 ? row[2].toString().trim() : '',
                price: row.length > 3 ? row[3].toString().trim() : '',
                rating: row.length > 4 ? row[4].toString().trim() : '',
                discount: row.length > 5 ? row[5].toString().trim() : '',
                category: row.length > 6 && row[6].toString().trim().isNotEmpty
                    ? row[6].toString().trim()
                    : 'أخرى',
                description: row.length > 7 ? row[7].toString().trim() : '',
              ),
            )
            .toList();
      } else {
        throw Exception(
          'فشل في جلب البيانات: رمز الخطأ ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('Error fetching data: $e');
      throw Exception('تعذر الاتصال بخادم البيانات. التفاصيل: $e');
    }
  }
}
