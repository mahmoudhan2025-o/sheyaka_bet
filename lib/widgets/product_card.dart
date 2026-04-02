import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';

import '../models/product.dart';
import '../services/product_providers.dart';
import '../services/chat_service.dart';
import '../config/app_config.dart';
import '../config/constants.dart';

/// بطاقة منتج تفاعلية مع تقييم وتعليقات
class ProductCard extends ConsumerStatefulWidget {
  final Product product;

  const ProductCard({super.key, required this.product});

  @override
  ConsumerState<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends ConsumerState<ProductCard> {
  bool _isHovering = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // تهيئة قيمة التقييم في Riverpod
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(ratingValueProvider(widget.product.name).notifier).state = 0.0;
        ref.read(commentTextProvider(widget.product.name).notifier).state = '';
      }
    });
  }

  @override
  void dispose() {
    // تنظيف Riverpod providers عند إزالة الويدجت
    ref.invalidate(commentTextProvider(widget.product.name));
    ref.invalidate(ratingValueProvider(widget.product.name));
    super.dispose();
  }

  Future<void> _submitReview() async {
    final rating = ref.read(ratingValueProvider(widget.product.name));
    final comment = ref.read(commentTextProvider(widget.product.name));

    if (comment.trim().isEmpty && rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الرجاء إضافة تعليق أو تقييم'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final baseUrl = AppConfig.reviewsApiUrl;

      if (baseUrl.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'خطأ: رابط API التقييمات غير متوفر! تأكد من ملف .env',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() => _isSubmitting = false);
        return;
      }

      final uri = Uri.parse(baseUrl);
      final finalUri = uri.replace(
        queryParameters: {
          ...uri.queryParameters,
          'productName': widget.product.name,
          'rating': rating.toString(),
          'comment': comment.trim().isEmpty ? 'بدون تعليق' : comment.trim(),
        },
      );

      await http.get(finalUri);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('شكراً لتقييمك!'),
            backgroundColor: Colors.green,
          ),
        );
        ref.read(ratingValueProvider(widget.product.name).notifier).state = 0.0;
        ref.read(commentTextProvider(widget.product.name).notifier).state = '';
      }
    } catch (e) {
      if (mounted) {
        final errorStr = e.toString().toLowerCase();
        if (errorStr.contains('xmlhttprequest') ||
            errorStr.contains('fetch') ||
            errorStr.contains('clientexception') ||
            errorStr.contains('cors')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('شكراً لتقييمك!'),
              backgroundColor: Colors.green,
            ),
          );
          ref.read(ratingValueProvider(widget.product.name).notifier).state =
              0.0;
          ref.read(commentTextProvider(widget.product.name).notifier).state =
              '';
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

  /// بناء شريط التقييم (النجوم)
  Widget _buildRatingBar() {
    final currentRating = ref.watch(ratingValueProvider(widget.product.name));

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(AppConstants.maxRating, (index) {
        return IconButton(
          icon: Icon(
            index < currentRating ? Icons.star : Icons.star_border,
            color: Colors.amber,
            size: 24,
          ),
          onPressed: () {
            ref.read(ratingValueProvider(widget.product.name).notifier).state =
                (index + 1).toDouble();
          },
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        );
      }),
    );
  }

  /// بناء حقل التعليق
  Widget _buildCommentField() {
    return TextField(
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
          borderSide: BorderSide(color: Colors.brown[200]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.brown),
        ),
      ),
      style: const TextStyle(fontSize: 12),
      onChanged: (value) {
        ref.read(commentTextProvider(widget.product.name).notifier).state =
            value;
      },
      maxLength: AppConstants.maxCommentLength,
    );
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
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          child: Column(
            children: [
              // صورة المنتج
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(15),
                      ),
                      child: Hero(
                        tag: 'image_${widget.product.name}',
                        child: CachedNetworkImage(
                          imageUrl: widget.product.imageUrl.isNotEmpty
                              ? widget.product.imageUrl
                              : 'https://via.placeholder.com/300',
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
                    if (widget.product.discount.isNotEmpty)
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
                            widget.product.discount,
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

              // اسم المنتج
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  widget.product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),

              // وصف مختصر
              if (widget.product.description.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8.0,
                    vertical: 2.0,
                  ),
                  child: Text(
                    widget.product.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ),

              // السعر
              if (widget.product.price.isNotEmpty &&
                  widget.product.price != 'Price not found')
                Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: Text(
                    '${widget.product.price} جنيه',
                    style: TextStyle(
                      color: Colors.green[800],
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),

              // التقييم
              if (widget.product.rating.isNotEmpty &&
                  widget.product.rating != 'Rating not found')
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        widget.product.rating,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),

              // أزرار الإجراءات
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Row(
                  children: [
                    // زر الشراء
                    Expanded(
                      child: Material(
                        color: Colors.brown,
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () {
                            launchUrl(Uri.parse(widget.product.link));
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
                    const SizedBox(width: 6),
                    // زر الواتساب
                    Material(
                      color: Colors.green[600],
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () async {
                          await ChatService.openWhatsApp(widget.product.name);
                        },
                        splashColor: Colors.white.withValues(alpha: 0.3),
                        highlightColor: Colors.green[700],
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 8,
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.chat,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                    // قائمة المشاركة
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.share, color: Colors.brown),
                      tooltip: 'خيارات المشاركة',
                      onSelected: (value) async {
                        final productUrl =
                            '${AppConstants.baseUrl}${AppConstants.productUrl(widget.product.name.hashCode.abs())}';
                        if (value == 'share') {
                          SharePlus.instance.share(
                            ShareParams(
                              text: 'شوف المنتج ده على شياكة : $productUrl',
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

              // قسم التقييم والتعليق
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
                    // شريط التقييم
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'التقييم: ',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          _buildRatingBar(),
                        ],
                      ),
                    ),
                    // حقل التعليق وزر الإرسال
                    Row(
                      children: [
                        Expanded(child: _buildCommentField()),
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
