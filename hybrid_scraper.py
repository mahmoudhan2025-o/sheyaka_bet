import sys
import io
import os
import time
import random
import re
from urllib.parse import urlparse, urlunparse
from flask import Flask, request, jsonify
import gspread
import requests
from bs4 import BeautifulSoup

# إعداد الترميز ليدعم اللغة العربية في الـ Console
if sys.stdout.encoding != 'utf-8':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

app = Flask(__name__)

# --- الإعدادات الثابتة ---
BASE_DIR = os.path.dirname(__file__)
SCOPES = ['https://www.googleapis.com/auth/spreadsheets', 'https://www.googleapis.com/auth/drive']
CREDENTIALS_FILENAME = 'credentials.json'
SHEET_URL = 'https://docs.google.com/spreadsheets/d/1h_WircIlH5FaSFA7FQsdlaurhw86U0t6bcv5hvvvhB8/edit?usp=sharing'
URLS_FILENAME = 'urls.txt'

USER_AGENTS = [
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:123.0) Gecko/20100101 Firefox/123.0',
    'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36'
]

class ScraperService:
    def __init__(self):
        self.session = requests.Session()
        self.gc = None
        self.worksheet = None
        self.existing_urls = []
        self._init_gsheets()

    def _init_gsheets(self):
        try:
            credentials_path = os.path.join(BASE_DIR, CREDENTIALS_FILENAME)
            self.gc = gspread.service_account(filename=credentials_path, scopes=SCOPES)
            self.worksheet = self.gc.open_by_url(SHEET_URL).sheet1
            raw_urls = self.worksheet.col_values(3)
            self.existing_urls = [self.clean_url(u) for u in raw_urls]
            print("✅ تم الاتصال بقاعدة بيانات جوجل بنجاح.")
        except Exception as e:
            print(f"❌ خطأ في الاتصال بجدول البيانات: {e}")

    def clean_url(self, url):
        parsed = urlparse(url)
        match = re.search(r'/(dp|gp/product|product)/([a-zA-Z0-9]{10})', parsed.path)
        if match:
            return f"https://{parsed.netloc}/dp/{match.group(2)}"
        return urlunparse((parsed.scheme, parsed.netloc, parsed.path, '', '', ''))

    def get_headers(self):
        return {
            'User-Agent': random.choice(USER_AGENTS),
            'Accept-Language': 'ar-AE,ar;q=0.9,en-US;q=0.8,en;q=0.7',
            'Accept-Encoding': 'gzip, deflate, br',
            'Connection': 'keep-alive',
            'Upgrade-Insecure-Requests': '1',
        }

    def scrape_product(self, raw_url):
        url = self.clean_url(raw_url)
        
        if url in self.existing_urls:
            return {"status": "skipped", "message": "المنتج موجود مسبقاً", "url": url}

        for attempt in range(3):
            try:
                response = self.session.get(url, headers=self.get_headers(), timeout=15)
                if response.status_code == 503 or 'api-services-support@amazon.com' in response.text:
                    time.sleep(10 + (attempt * 5))
                    continue
                response.raise_for_status()
                
                soup = BeautifulSoup(response.content, 'html.parser')
                
                title = t.get_text(strip=True) if (t := soup.find(id='productTitle')) else 'Title not found'
                price = p.get_text(strip=True) if (p := soup.select_one('span.a-price-whole')) else 'Price not found'
                image_url = img.get('src', '') if (img := soup.find(id='landingImage')) else ''
                rating = r.get_text(strip=True) if (r := soup.select_one('#averageCustomerReviews span.a-icon-alt')) else '0'
                discount = d.get_text(strip=True) if (d := soup.select_one('span.savingsPercentage')) else ''
                
                breadcrumbs = soup.select('#wayfinding-breadcrumbs_feature_div a.a-link-normal')
                category = breadcrumbs[0].get_text(strip=True) if breadcrumbs else 'أخرى'
                
                bullets = soup.select('#feature-bullets ul li span.a-list-item')
                desc_items = [b.get_text(strip=True) for b in bullets if b.get_text(strip=True)]
                description = ' - '.join(desc_items[:3]) if desc_items else ''

                sheet_image = f'=IMAGE("{image_url}")' if image_url else ''
                safe_title = f"'{title}" if title.startswith(('=', '+', '-', '@')) else title
                safe_desc = f"'{description}" if description.startswith(('=', '+', '-', '@')) else description

                product_data = [safe_title, sheet_image, url, price, rating, discount, category, safe_desc]
                
                if self.worksheet:
                    self.worksheet.append_row(product_data)
                    self.existing_urls.append(url)
                    return {"status": "success", "title": safe_title, "url": url}
                    
            except Exception as e:
                if attempt == 2:
                    return {"status": "error", "message": str(e), "url": url}
                time.sleep(random.uniform(3, 7))

scraper_service = ScraperService()

# --- مسارات API (Flask Routes) ---

@app.route('/api/scrape', methods=['POST'])
def api_scrape():
    """استقبال رابط واحد أو قائمة روابط من إضافة الكروم أو أي تطبيق آخر"""
    data = request.json
    if not data or 'urls' not in data:
        return jsonify({"error": "يرجى توفير قائمة 'urls' في جسم الطلب"}), 400
        
    urls = data['urls']
    results = []
    
    for index, url in enumerate(urls):
        res = scraper_service.scrape_product(url)
        results.append(res)
        # تأخير زمني عشوائي بين الطلبات إذا كان هناك أكثر من رابط
        if index < len(urls) - 1:
            time.sleep(random.uniform(4, 9))
            
    return jsonify({"results": results})

@app.route('/api/process_file', methods=['GET', 'POST'])
def api_process_file():
    """قراءة الروابط من الملف المحلي وإضافتها"""
    urls_path = os.path.join(BASE_DIR, URLS_FILENAME)
    if not os.path.exists(urls_path):
        return jsonify({"error": f"الملف {URLS_FILENAME} غير موجود"}), 404
        
    with open(urls_path, 'r', encoding='utf-8') as f:
        urls = [line.strip() for line in f if line.strip()]
        
    if not urls:
        return jsonify({"message": "الملف فارغ"}), 200
        
    # تشغيل المعالجة في الخلفية (أو في نفس الوقت للحظات القليلة)
    results = []
    for index, url in enumerate(urls):
        res = scraper_service.scrape_product(url)
        results.append(res)
        if index < len(urls) - 1:
            time.sleep(random.uniform(5, 10))
            
    return jsonify({"message": "تمت معالجة الملف", "results": results})

if __name__ == '__main__':
    print("🚀 بدء تشغيل خادم Flask لروبوت السحب...")
    # تشغيل الخادم على المنفذ 5000
    app.run(host='0.0.0.0', port=5000, debug=True)