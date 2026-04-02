import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'screens/home_screen.dart';

// أداة ProviderObserver لمراقبة أداء وحالة الـ Riverpod
class AppObserver extends ProviderObserver {
  @override
  void didAddProvider(
    ProviderBase<Object?> provider,
    Object? value,
    ProviderContainer container,
  ) {
    debugPrint(
      '🟢 Riverpod: تم تشغيل (Initialize) => ${provider.name ?? provider.runtimeType}',
    );
  }

  @override
  void didUpdateProvider(
    ProviderBase<Object?> provider,
    Object? previousValue,
    Object? newValue,
    ProviderContainer container,
  ) {
    debugPrint(
      '🔄 Riverpod: تم تحديث (Update) => ${provider.name ?? provider.runtimeType}',
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // إزالة علامة الـ Hash (#) من روابط الويب لتحسين الـ SEO
  usePathUrlStrategy();

  // تحميل ملف المتغيرات البيئية
  await dotenv.load(fileName: ".env");

  runApp(ProviderScope(observers: [AppObserver()], child: const SheyakaApp()));
}

class SheyakaApp extends StatelessWidget {
  const SheyakaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'شياكة بيت ✨',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: Colors.brown,
        scaffoldBackgroundColor: Colors.white,
        textTheme: GoogleFonts.cairoTextTheme(Theme.of(context).textTheme),
        colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.brown),
      ),
      home: const HomePage(),
    );
  }
}
