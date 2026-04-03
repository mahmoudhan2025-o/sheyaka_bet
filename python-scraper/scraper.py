import sys
import io
if sys.stdout.encoding != 'utf-8':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

import gspread
import requests
from bs4 import BeautifulSoup
import os
import time
import random
from urllib.parse import urlparse, urlunparse
import re

# تحديد مسار المجلد الأساسي لتجنب تكرار الكود
BASE_DIR = os.path.dirname(__file__)

# --- الإعدادات ---
# تحديد نطاقات الوصول المطلوبة
SCOPES = [
    'https://www.googleapis.com/auth/spreadsheets',
    'https://www.googleapis.com/auth/drive'
]

# اسم ملف الصلاحيات (يفترض أنه في نفس مجلد السكربت)
CREDENTIALS_FILENAME = 'credentials.json'

# رابط جدول البيانات في جوجل شيت (انسخه بالكامل من المتصفح)
# استخدام الرابط يضمن الوصول المباشر ويتجنب أخطاء 403 (Permission Denied)
SHEET_URL = 'https://docs.google.com/spreadsheets/d/1h_WircIlH5FaSFA7FQsdlaurhw86U0t6bcv5hvvvhB8/edit?usp=sharing'

# اسم ملف الروابط النصي
URLS_FILENAME = 'urls.txt'

# قائمة User-Agents حديثة لتجنب الحظر
USER_AGENTS = [
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:123.0) Gecko/20100101 Firefox/123.0',
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:123.0) Gecko/20100101 Firefox/123.0',
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Edge/122.0.0.0 Safari/537.36',
    'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36'
]

def clean_amazon_url(url):
    """
    تنظيف رابط أمازون من إضافات التتبع (Tracking parameters)
    لضمان عدم تكرار نفس المنتج إذا اختلفت الإضافات في الرابط.
    """
    parsed = urlparse(url)
    
    # محاولة استخراج المعرف الفريد للمنتج (ASIN) من الروابط الطويلة
    match = re.search(r'/(dp|gp/product|product)/([a-zA-Z0-9]{10})', parsed.path)
    if match:
        return f"https://{parsed.netloc}/dp/{match.group(2)}"
    
    # إذا كان رابطاً مختصراً (مثل amzn.to)، نكتفي بإزالة الـ Query Parameters (مثل ?ref=...)
    return urlunparse((parsed.scheme, parsed.netloc, parsed.path, '', '', ''))

def scrape_amazon_product(url, session):
    """
    تقوم هذه الدالة بسحب العنوان، السعر، ورابط الصورة من صفحة منتج على أمازون.
    """
    
    print(f"جاري سحب البيانات من: {url}")
    
    # نظام إعادة المحاولة لتجنب أخطاء الشبكة المؤقتة (3 محاولات كحد أقصى)
    max_retries = 3
    response = None
    for attempt in range(max_retries):
        try:
            response = session.get(url, timeout=20)
            
            # اكتشاف صفحات الكابتشا (CAPTCHA) أو رسائل الـ 503
            if response.status_code == 503 or 'api-services-support@amazon.com' in response.text:
                wait_time = 15 + (attempt * 10)
                print(f"⚠️ تم اكتشاف حظر مؤقت (CAPTCHA/503). جاري الانتظار {wait_time} ثانية...")
                time.sleep(wait_time)
                continue
                
            response.raise_for_status()
            break  # الخروج من حلقة الإعادة إذا نجح الطلب
        except Exception as e:
            if attempt < max_retries - 1:
                wait_time = random.uniform(5, 10) * (attempt + 1)
                print(f"⚠️ خطأ في الاتصال. جاري المحاولة {attempt + 2}/{max_retries} بعد {wait_time:.1f} ثواني...")
                time.sleep(wait_time)
            else:
                print(f"❌ فشل السحب تماماً بعد {max_retries} محاولات: {e}")
                return None

    try:
        soup = BeautifulSoup(response.content, 'html.parser')
        
        # --- سحب البيانات ---
        title = t.get_text(strip=True) if (t := soup.find(id='productTitle')) else 'Title not found'
        price = p.get_text(strip=True) if (p := soup.select_one('span.a-price-whole')) else 'Price not found'
        image_url = img.get('src', 'Image not found') if (img := soup.find(id='landingImage')) else 'Image not found'
        
        # --- سحب التقييم (مثال: 4.5 من 5 نجوم) ---
        rating = r.get_text(strip=True) if (r := soup.select_one('#averageCustomerReviews span.a-icon-alt')) else 'Rating not found'
        
        # --- سحب نسبة الخصم (مثال: -20%) ---
        discount = d.get_text(strip=True) if (d := soup.select_one('span.savingsPercentage')) else ''
        
        # --- سحب قسم المنتج (Category) من مسار التنقل (Breadcrumbs) ---
        breadcrumbs = soup.select('#wayfinding-breadcrumbs_feature_div a.a-link-normal')
        category = breadcrumbs[0].get_text(strip=True) if breadcrumbs else 'أخرى'
        
        # --- سحب الوصف (من النقاط البارزة أو وصف المنتج) ---
        bullets = soup.select('#feature-bullets ul li span.a-list-item')
        if bullets:
            desc_items = [b.get_text(strip=True) for b in bullets if b.get_text(strip=True)]
            description = ' - '.join(desc_items[:3]) # أخذ أول 3 نقاط ودمجها
        else:
            desc_div = soup.select_one('#productDescription p, #productDescription span')
            description = desc_div.get_text(strip=True) if desc_div else ''

        print("تم سحب البيانات بنجاح.")
        
        # تحويل الرابط إلى دالة صورة ليتم عرضها داخل الخلية في جوجل شيت
        sheet_image = f'=IMAGE("{image_url}")' if image_url != 'Image not found' and image_url.startswith('http') else image_url
        
        # حماية البيانات من ثغرة حقن المعادلات (Formula Injection) في جوجل شيت
        safe_title = f"'{title}" if title.startswith(('=', '+', '-', '@')) else title
        safe_description = f"'{description}" if description.startswith(('=', '+', '-', '@')) else description

        # الترتيب الجديد: العنوان، رابط الصورة، رابط المنتج، السعر، التقييم، نسبة الخصم، القسم، الوصف
        return [safe_title, sheet_image, url, price, rating, discount, category, safe_description]
        
    except Exception as e:
        print(f"حدث خطأ أثناء عملية السحب: {e}")
        return None

def get_urls_from_file(filename):
    """قراءة الروابط من ملف نصي وإرجاعها كقائمة."""
    urls_path = os.path.join(BASE_DIR, filename)
    if not os.path.exists(urls_path):
        print(f"تنبيه: ملف الروابط '{filename}' غير موجود. سيتم إنشاء ملف فارغ.")
        # إنشاء ملف فارغ لتسهيل الأمر على المستخدم
        open(urls_path, 'w', encoding='utf-8').close()
        return []
    
    with open(urls_path, 'r', encoding='utf-8') as f:
        return [line.strip() for line in f if line.strip()]

def main():
    """
    الدالة الرئيسية للمصادقة، السحب، وتحديث جدول بيانات جوجل.
    """
    print("--- بدء تشغيل روبوت البايثون ---")
    
    try:
        # الحصول على المسار الكامل لملف الصلاحيات
        credentials_path = os.path.join(BASE_DIR, CREDENTIALS_FILENAME)
        gc = gspread.service_account(filename=credentials_path, scopes=SCOPES)
        
        # فتح جدول البيانات باستخدام الرابط المباشر والوصول للورقة الأولى
        worksheet = gc.open_by_url(SHEET_URL).sheet1
        print("تم الاتصال بنجاح بجدول البيانات!")
        
        # جلب الروابط الموجودة مسبقاً في الشيت (العمود الثالث) لتجنب التكرار
        raw_existing_urls = worksheet.col_values(3)
        # تنظيف الروابط الموجودة مسبقاً في الذاكرة لتجنب التكرار
        existing_urls = [clean_amazon_url(u) for u in raw_existing_urls]
    except Exception as e:
        print(f"خطأ في الاتصال بـ Google Sheets: {e}")
        print("الرجاء التأكد من وجود ملف 'credentials.json' ومشاركة الجدول مع 'client_email' الموجود داخل الملف.")
        return

    # --- قراءة الروابط من الملف ---
    amazon_urls = get_urls_from_file(URLS_FILENAME)
    if not amazon_urls:
        print(f"لم يتم العثور على روابط. يرجى إضافة روابط أمازون إلى ملف '{URLS_FILENAME}' والمحاولة مرة أخرى.")
        return

    # --- إنشاء جلسة (Session) للحفاظ على الـ Cookies ---
    session = requests.Session()
    
    # إعداد الترويسات مرة واحدة لكامل الجلسة لتبدو كمستخدم حقيقي يتصفح المتجر
    session.headers.update({
        'User-Agent': random.choice(USER_AGENTS),
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7',
        'Accept-Language': 'ar-AE,ar;q=0.9,en-US;q=0.8,en;q=0.7',
        'Accept-Encoding': 'gzip, deflate, br',
        'Connection': 'keep-alive',
        'Upgrade-Insecure-Requests': '1',
        'Sec-Fetch-Dest': 'document',
        'Sec-Fetch-Mode': 'navigate',
        'Sec-Fetch-Site': 'cross-site',
        'Cache-Control': 'max-age=0'
    })

    # --- سحب البيانات من أمازون لجميع الروابط المحددة ---
    for index, raw_url in enumerate(amazon_urls):
        url = clean_amazon_url(raw_url)
        
        # التحقق مما إذا كان الرابط موجوداً بالفعل
        if url in existing_urls:
            print(f"⏭️ المنتج موجود مسبقاً، سيتم تخطيه: {url}\n")
            continue
            
        product_data = scrape_amazon_product(url, session)
        
        # --- إضافة البيانات إلى الجدول ---
        if product_data:
            try:
                worksheet.append_row(product_data)
                existing_urls.append(url) # تحديث القائمة المحلية لتجنب تكرار نفس الرابط في نفس الجلسة
                print(f"✅ تمت إضافة صف جديد بنجاح يحتوي على: {product_data[0]}\n")
            except Exception as e:
                print(f"❌ خطأ في إضافة صف إلى جدول البيانات: {e}\n")
                
        # إضافة تأخير زمني عشوائي لتجنب الحظر (إلا بعد العنصر الأخير)
        if index < len(amazon_urls) - 1:
            delay = random.uniform(5, 12) # تأخير زمني أطول وأكثر عشوائية
            print(f"⏳ انتظار {delay:.1f} ثانية قبل المنتج التالي لتجنب حظر الـ IP...")
            time.sleep(delay)
            
    print("--- انتهى عمل روبوت البايثون ---")

if __name__ == '__main__':
    main()