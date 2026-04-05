import os
import asyncio
import re
import random
import requests
import base64
from telegram import Update, ReplyKeyboardMarkup, ReplyKeyboardRemove
from telegram.ext import Application, CommandHandler, MessageHandler, filters, ContextTypes, ConversationHandler
import gspread
from scraper import clean_amazon_url, scrape_amazon_product, USER_AGENTS

# --- الإعدادات ---
# التوكن الخاص ببوت تليجرام
TOKEN = "8669091123:AAGQxN5A3UxCe4mqVfi4hkOin-2CM-sZBN0"
# رابط جوجل شيت (نفس الرابط المستخدم في السكربت الآخر)
SHEET_URL = 'https://docs.google.com/spreadsheets/d/1h_WircIlH5FaSFA7FQsdlaurhw86U0t6bcv5hvvvhB8/edit?usp=sharing'
CREDENTIALS_FILENAME = 'credentials.json'

# مفتاح API لخدمة ImgBB لرفع الصور وتوليد روابط دائمة
IMGBB_API_KEY = "72491e273f35eb956f72521340a963f1"

# حالات المحادثة
NAME, IMAGE, LINK, PRICE, CATEGORY, DESC, CONFIRM = range(7)
# حالات محادثة التعديل
EDIT_SEARCH, EDIT_SELECT, EDIT_FIELD, EDIT_VALUE = range(7, 11)
# حالات محادثة الحذف
DEL_SEARCH, DEL_SELECT, DEL_CONFIRM = range(11, 14)

# اتصال قاعدة البيانات (Google Sheets) مرة واحدة لتسريع البوت
base_dir = os.path.dirname(__file__)
cred_path = os.path.join(base_dir, CREDENTIALS_FILENAME)
gc = gspread.service_account(filename=cred_path, scopes=[
    'https://www.googleapis.com/auth/spreadsheets',
    'https://www.googleapis.com/auth/drive'
])
sheet = gc.open_by_url(SHEET_URL).sheet1

async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    await update.message.reply_text(
        "أهلاً بك يا مدير! 👨‍💼\n"
        "أنا بوت 'شياكة' لإضافة المنتجات.\n\n"
        "📱 **لمنتجات الواتساب:** أرسل الأمر /add_product للإضافة الفورية.\n"
        "🔗 **لمنتجات أمازون:** أرسل الرابط مباشرة في رسالة وسأقوم بسحبه ببطء لتجنب الحظر.\n"
        "📊 **للإحصائيات:** أرسل الأمر /stats لمعرفة عدد منتجات الموقع.\n"
        "✏️ **للتعديل:** أرسل الأمر /edit_product لتعديل بيانات أي منتج.\n"
        "🗑️ **للحذف:** أرسل الأمر /delete_product لمسح أي منتج نهائياً."
    )

async def add_product(update: Update, context: ContextTypes.DEFAULT_TYPE):
    await update.message.reply_text("يلا بينا! أدخل **اسم المنتج**:")
    return NAME

async def get_name(update: Update, context: ContextTypes.DEFAULT_TYPE):
    text = update.message.text
    
    # التحقق مما إذا كان المستخدم قد أرسل رابط أمازون بالخطأ بدلاً من اسم المنتج
    urls = re.findall(r'(https?://[^\s]+)', text)
    amazon_urls = [url for url in urls if 'amazon' in url or 'amzn.to' in url]
    if amazon_urls:
        await update.message.reply_text("💡 لاحظت أنك أرسلت رابط أمازون بدلاً من اسم المنتج!\nسيتم إلغاء الإضافة اليدوية للواتساب، وسأقوم بسحب الرابط تلقائياً في الخلفية... 🚀")
        asyncio.create_task(process_amazon_links(amazon_urls, update.message.chat_id, context))
        return ConversationHandler.END
        
    context.user_data['name'] = text
    await update.message.reply_text("ممتاز. الآن **أرسل صورة المنتج مباشرة من هاتفك** 📸\n(أو يمكنك إرسال رابط الصورة كالسابق)")
    return IMAGE

async def get_image(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if update.message.photo:
        await update.message.reply_text("⏳ جاري رفع الصورة وتوليد رابط دائم لها...")
        # أخذ أكبر دقة للصورة المرفوعة
        photo_file = await update.message.photo[-1].get_file()
        photo_bytes = await photo_file.download_as_bytearray()
        
        try:
            # الرفع إلى ImgBB عبر مسار منفصل
            response = await asyncio.to_thread(
                requests.post,
                f"https://api.imgbb.com/1/upload?key={IMGBB_API_KEY}",
                data={"image": base64.b64encode(photo_bytes).decode('utf-8')}
            )
            result = response.json()
            if result.get("success"):
                context.user_data['image'] = result["data"]["url"]
            else:
                await update.message.reply_text("❌ فشل رفع الصورة، تأكد من مفتاح ImgBB أو أرسل رابطاً يدوياً.")
                return IMAGE
        except Exception as e:
            await update.message.reply_text(f"❌ خطأ أثناء الرفع: {e}")
            return IMAGE
    else:
        context.user_data['image'] = update.message.text
        
    await update.message.reply_text(
        "حلو جداً. أرسل **رابط الشراء**:\n"
        "(لو المنتج من أمازون ضع رابطه، ولو كان منتجك الخاص الذي ستبيعه واتساب اكتب كلمة `wa.me` أو اتركه فارغاً وضع `لا`)"
    )
    return LINK

async def get_link(update: Update, context: ContextTypes.DEFAULT_TYPE):
    link = update.message.text
    context.user_data['link'] = "" if link == "لا" else link
    await update.message.reply_text("أدخل **سعر المنتج** (مثال: 150):")
    return PRICE

async def get_price(update: Update, context: ContextTypes.DEFAULT_TYPE):
    context.user_data['price'] = update.message.text
    
    # إعداد أزرار الأقسام (يمكنك تعديلها أو إضافة المزيد)
    reply_keyboard = [
        ['أدوات مطبخ', 'ديكور وأثاث'],
        ['إلكترونيات', 'العناية والجمال'],
        ['ملابس', 'أخرى']
    ]
    markup = ReplyKeyboardMarkup(reply_keyboard, one_time_keyboard=True, resize_keyboard=True)
    
    await update.message.reply_text(
        "ممتاز! الآن اختر **قسم المنتج** من الأزرار بالأسفل (أو اكتب قسماً جديداً إذا لم يكن موجوداً):",
        reply_markup=markup
    )
    return CATEGORY

async def get_category(update: Update, context: ContextTypes.DEFAULT_TYPE):
    context.user_data['category'] = update.message.text
    await update.message.reply_text("أخيراً، أدخل **وصف المنتج**:", reply_markup=ReplyKeyboardRemove())
    return DESC

async def get_desc(update: Update, context: ContextTypes.DEFAULT_TYPE):
    context.user_data['desc'] = update.message.text
    data = context.user_data
    
    # إنشاء رسالة المعاينة
    preview_text = (
        "👀 معاينة المنتج قبل النشر:\n\n"
        f"🏷️ الاسم: {data['name']}\n"
        f"💰 السعر: {data['price']} جنيه\n"
        f"📂 القسم: {data['category']}\n"
        f"🔗 الرابط: {data['link'] if data['link'] else 'واتساب'}\n"
        f"📝 الوصف: {data['desc']}\n\n"
        "هل تريد تأكيد وحفظ هذا المنتج؟"
    )
    
    reply_keyboard = [['✅ تأكيد', '❌ إلغاء']]
    markup = ReplyKeyboardMarkup(reply_keyboard, one_time_keyboard=True, resize_keyboard=True)
    
    # إرسال الصورة مع المعاينة
    if data['image'].startswith('http'):
        try:
            await update.message.reply_photo(photo=data['image'], caption=preview_text, reply_markup=markup)
        except:
            await update.message.reply_text(f"🖼️ رابط الصورة: {data['image']}\n\n{preview_text}", reply_markup=markup)
    else:
        await update.message.reply_text(preview_text, reply_markup=markup)
        
    return CONFIRM

async def confirm_save(update: Update, context: ContextTypes.DEFAULT_TYPE):
    choice = update.message.text
    
    # قبول الضغط على الزر أو كتابة "نعم" أو "تأكيد" يدوياً
    if choice == '✅ تأكيد' or 'تأكيد' in choice or 'نعم' in choice or choice.lower() in ['yes', 'y']:
        data = context.user_data
        try:
            # الترتيب: [العنوان، رابط الصورة، الرابط، السعر، التقييم، نسبة الخصم، القسم، الوصف]
            row = [data['name'], data['image'], data['link'], data['price'], "5.0", "", data['category'], data['desc']]
            
            # إضافة البيانات بدون تجميد البوت
            await asyncio.to_thread(sheet.append_row, row)
            
            await update.message.reply_text("✅ تم إضافة المنتج بنجاح ويظهر في الموقع فوراً!", reply_markup=ReplyKeyboardRemove())
        except Exception as e:
            await update.message.reply_text(f"❌ حدث خطأ أثناء الإضافة: {e}", reply_markup=ReplyKeyboardRemove())
    else:
        await update.message.reply_text("تم إلغاء حفظ المنتج 🗑️", reply_markup=ReplyKeyboardRemove())

    return ConversationHandler.END

async def cancel(update: Update, context: ContextTypes.DEFAULT_TYPE):
    await update.message.reply_text("تم إلغاء الإضافة.", reply_markup=ReplyKeyboardRemove())
    return ConversationHandler.END

async def get_stats(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """جلب إحصائيات المنتجات من جوجل شيت"""
    message = await update.message.reply_text("📊 جاري جلب الإحصائيات من الموقع، لحظات...")
    
    try:
        # جلب كل البيانات من الشيت في مسار منفصل
        records = await asyncio.to_thread(sheet.get_all_values)
        
        if not records or len(records) <= 1:
            await message.edit_text("الموقع فارغ حالياً! لا يوجد أي منتجات.")
            return
            
        # تجاهل صف العناوين الأول
        data = records[1:]
        total = len(data)
        amazon_count = sum(1 for row in data if len(row) > 2 and ('amazon' in row[2].lower() or 'amzn.to' in row[2].lower()))
        whatsapp_count = sum(1 for row in data if len(row) > 2 and ('wa.me' in row[2].lower() or row[2] == 'لا' or row[2] == ''))
        other_count = total - (amazon_count + whatsapp_count)
        
        stats_text = (
            f"📈 **إحصائيات متجر شياكة** 📈\n\n"
            f"📦 **إجمالي المنتجات:** {total}\n"
            f"🛒 **منتجات أمازون:** {amazon_count}\n"
            f"💬 **منتجات الواتساب:** {whatsapp_count}\n"
        )
        if other_count > 0:
            stats_text += f"🔗 **منتجات أخرى:** {other_count}\n"
            
        await message.edit_text(stats_text, parse_mode='Markdown')
        
    except Exception as e:
        await message.edit_text(f"❌ حدث خطأ أثناء جلب الإحصائيات: {e}")

async def edit_product_start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    await update.message.reply_text("🔍 أدخل **اسم المنتج** (أو جزء من اسمه) للبحث عنه وتعديله:")
    return EDIT_SEARCH

async def edit_search(update: Update, context: ContextTypes.DEFAULT_TYPE):
    search_term = update.message.text.lower()
    message = await update.message.reply_text("⏳ جاري البحث في الموقع...")

    try:
        records = await asyncio.to_thread(sheet.get_all_values)
        matches = []
        # تخطي صف العناوين الأول (i=0) والبحث في الباقي
        for i, row in enumerate(records):
            if i > 0 and len(row) > 0 and search_term in row[0].lower():
                matches.append((i + 1, row)) # +1 لأن جوجل شيت يبدأ العد من 1

        if not matches:
            await message.edit_text("❌ لم يتم العثور على أي منتج يطابق هذا الاسم.\nجرب اسماً آخر أو أرسل /cancel للإلغاء.")
            return EDIT_SEARCH

        context.user_data['edit_matches'] = matches[:10] # عرض أول 10 نتائج كحد أقصى
        
        text = "✅ تم العثور على المنتجات التالية:\n\n"
        for idx, (row_num, row) in enumerate(context.user_data['edit_matches']):
            price = row[3] if len(row) > 3 else 'غير محدد'
            text += f"*{idx + 1}*. {row[0]} - ({price} جنيه)\n"

        text += "\n🔢 **أرسل رقم المنتج** الذي تريد تعديله (مثال: 1):"
        await message.edit_text(text, parse_mode='Markdown')
        return EDIT_SELECT

    except Exception as e:
        await message.edit_text(f"❌ حدث خطأ: {e}")
        return ConversationHandler.END

async def edit_select(update: Update, context: ContextTypes.DEFAULT_TYPE):
    try:
        choice = int(update.message.text) - 1
        matches = context.user_data.get('edit_matches', [])
        
        if choice < 0 or choice >= len(matches):
            raise ValueError()
            
        selected_row_num, selected_row_data = matches[choice]
        context.user_data['edit_row_num'] = selected_row_num
        context.user_data['edit_row_data'] = selected_row_data

        reply_keyboard = [['السعر', 'الوصف'], ['الاسم', 'القسم'], ['الرابط', 'إلغاء']]
        markup = ReplyKeyboardMarkup(reply_keyboard, one_time_keyboard=True, resize_keyboard=True)
        
        await update.message.reply_text(f"📝 لقد اخترت:\n{selected_row_data[0]}\n\nما الذي تريد تعديله؟", reply_markup=markup)
        return EDIT_FIELD
        
    except ValueError:
        await update.message.reply_text("❌ يرجى إدخال رقم صحيح من القائمة:")
        return EDIT_SELECT

async def edit_field(update: Update, context: ContextTypes.DEFAULT_TYPE):
    field = update.message.text
    if field == 'إلغاء':
        await update.message.reply_text("تم إلغاء التعديل.", reply_markup=ReplyKeyboardRemove())
        return ConversationHandler.END
        
    field_map = {'الاسم': 1, 'الصورة': 2, 'الرابط': 3, 'السعر': 4, 'القسم': 7, 'الوصف': 8}
    if field not in field_map:
        await update.message.reply_text("❌ اختيار غير صحيح.")
        return EDIT_FIELD
        
    context.user_data['edit_col_num'] = field_map[field]
    context.user_data['edit_field_name'] = field
    
    current_val = context.user_data['edit_row_data'][field_map[field]-1] if len(context.user_data['edit_row_data']) >= field_map[field] else 'فارغ'
    
    await update.message.reply_text(f"✏️ القيمة الحالية لـ ({field}) هي:\n{current_val}\n\n**أرسل القيمة الجديدة الآن:**", reply_markup=ReplyKeyboardRemove())
    return EDIT_VALUE

async def edit_value(update: Update, context: ContextTypes.DEFAULT_TYPE):
    new_value = update.message.text
    row_num = context.user_data['edit_row_num']
    col_num = context.user_data['edit_col_num']
    field_name = context.user_data['edit_field_name']
    
    message = await update.message.reply_text("⏳ جاري تحديث البيانات...")
    
    try:
        await asyncio.to_thread(sheet.update_cell, row_num, col_num, new_value)
        await message.edit_text(f"✅ تم تعديل {field_name} بنجاح والتحديث في الموقع!")
    except Exception as e:
        await message.edit_text(f"❌ حدث خطأ أثناء التعديل: {e}")
        
    return ConversationHandler.END

async def delete_product_start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    await update.message.reply_text("🗑️ أدخل **اسم المنتج** (أو جزء من اسمه) للبحث عنه وحذفه:")
    return DEL_SEARCH

async def delete_search(update: Update, context: ContextTypes.DEFAULT_TYPE):
    search_term = update.message.text.lower()
    message = await update.message.reply_text("⏳ جاري البحث في الموقع...")

    try:
        records = await asyncio.to_thread(sheet.get_all_values)
        matches = []
        for i, row in enumerate(records):
            if i > 0 and len(row) > 0 and search_term in row[0].lower():
                matches.append((i + 1, row))

        if not matches:
            await message.edit_text("❌ لم يتم العثور على أي منتج يطابق هذا الاسم.\nجرب اسماً آخر أو أرسل /cancel للإلغاء.")
            return DEL_SEARCH

        context.user_data['del_matches'] = matches[:10]
        
        text = "✅ تم العثور على المنتجات التالية:\n\n"
        for idx, (row_num, row) in enumerate(context.user_data['del_matches']):
            price = row[3] if len(row) > 3 else 'غير محدد'
            text += f"*{idx + 1}*. {row[0]} - ({price} جنيه)\n"

        text += "\n🔢 **أرسل رقم المنتج** الذي تريد حذفه (مثال: 1):"
        await message.edit_text(text, parse_mode='Markdown')
        return DEL_SELECT

    except Exception as e:
        await message.edit_text(f"❌ حدث خطأ: {e}")
        return ConversationHandler.END

async def delete_select(update: Update, context: ContextTypes.DEFAULT_TYPE):
    try:
        choice = int(update.message.text) - 1
        matches = context.user_data.get('del_matches', [])
        
        if choice < 0 or choice >= len(matches):
            raise ValueError()
            
        selected_row_num, selected_row_data = matches[choice]
        context.user_data['del_row_num'] = selected_row_num

        reply_keyboard = [['⚠️ تأكيد الحذف', '❌ إلغاء']]
        markup = ReplyKeyboardMarkup(reply_keyboard, one_time_keyboard=True, resize_keyboard=True)
        
        await update.message.reply_text(
            f"⚠️ تحذير: هل أنت متأكد أنك تريد حذف هذا المنتج نهائياً من الموقع؟\n\n{selected_row_data[0]}",
            reply_markup=markup
        )
        return DEL_CONFIRM
        
    except ValueError:
        await update.message.reply_text("❌ يرجى إدخال رقم صحيح من القائمة:")
        return DEL_SELECT

async def delete_confirm(update: Update, context: ContextTypes.DEFAULT_TYPE):
    choice = update.message.text
    # قبول الضغط على الزر أو كتابة "نعم" أو "تأكيد" يدوياً
    if choice == '⚠️ تأكيد الحذف' or 'تأكيد' in choice or 'نعم' in choice or choice.lower() in ['yes', 'y']:
        row_num = context.user_data['del_row_num']
        message = await update.message.reply_text("⏳ جاري الحذف من الموقع...", reply_markup=ReplyKeyboardRemove())
        try:
            await asyncio.to_thread(sheet.delete_row, row_num)
            await message.edit_text("✅ تم مسح المنتج بنجاح من الموقع!")
        except Exception as e:
            await message.edit_text(f"❌ حدث خطأ أثناء الحذف: {e}")
    else:
        await update.message.reply_text("تم إلغاء الحذف.", reply_markup=ReplyKeyboardRemove())
        
    return ConversationHandler.END

async def process_amazon_links(urls, chat_id, context):
    """دالة تعمل في الخلفية لسحب منتجات أمازون ببطء لتجنب الحظر"""
    session = requests.Session()
    session.headers.update({
        'User-Agent': random.choice(USER_AGENTS),
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'ar-AE,ar;q=0.9,en-US;q=0.8,en;q=0.7',
    })
    
    for index, raw_url in enumerate(urls):
        url = clean_amazon_url(raw_url)
        await context.bot.send_message(chat_id=chat_id, text=f"⏳ جاري سحب بيانات الرابط ({index+1}/{len(urls)})...")
        
        # السحب في مسار منفصل (Thread) لتجنب تجميد البوت
        product_data = await asyncio.to_thread(scrape_amazon_product, url, session)
        
        if product_data:
            try:
                await asyncio.to_thread(sheet.append_row, product_data)
                await context.bot.send_message(chat_id=chat_id, text=f"✅ تمت الإضافة بنجاح:\n{product_data[0]}")
            except Exception as e:
                await context.bot.send_message(chat_id=chat_id, text=f"❌ خطأ أثناء الإضافة للشيت: {e}")
        else:
            await context.bot.send_message(chat_id=chat_id, text=f"❌ فشل سحب البيانات من الرابط (قد يكون محظور مؤقتاً).")
        
        # تأخير زمني عشوائي لتجنب الحظر إذا كان هناك المزيد من الروابط
        if index < len(urls) - 1:
            delay = random.uniform(12, 25)
            await context.bot.send_message(chat_id=chat_id, text=f"💤 انتظار {int(delay)} ثانية لتجنب حظر أمازون...")
            await asyncio.sleep(delay)

async def handle_direct_messages(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """التعامل مع الرسائل المباشرة (استخراج روابط أمازون)"""
    text = update.message.text
    urls = re.findall(r'(https?://[^\s]+)', text)
    amazon_urls = [url for url in urls if 'amazon' in url or 'amzn.to' in url]
    
    if amazon_urls:
        await update.message.reply_text(f"🔍 تم اكتشاف {len(amazon_urls)} رابط أمازون.\nسيتم سحبها وإضافتها للموقع في الخلفية ببطء لتجنب الحظر...")
        asyncio.create_task(process_amazon_links(amazon_urls, update.message.chat_id, context))
    else:
        await update.message.reply_text("عفواً، لم أفهم. لإضافة منتج محلي أرسل /add_product\nأو قم بإرسال روابط أمازون مباشرة لسحبها تلقائياً.")

def main():
    app = Application.builder().token(TOKEN).build()

    conv_handler = ConversationHandler(
        entry_points=[CommandHandler('add_product', add_product)],
        states={
            NAME: [MessageHandler(filters.TEXT & ~filters.COMMAND, get_name)],
            IMAGE: [MessageHandler((filters.TEXT | filters.PHOTO) & ~filters.COMMAND, get_image)],
            LINK: [MessageHandler(filters.TEXT & ~filters.COMMAND, get_link)],
            PRICE: [MessageHandler(filters.TEXT & ~filters.COMMAND, get_price)],
            CATEGORY: [MessageHandler(filters.TEXT & ~filters.COMMAND, get_category)],
            DESC: [MessageHandler(filters.TEXT & ~filters.COMMAND, get_desc)],
            CONFIRM: [MessageHandler(filters.TEXT & ~filters.COMMAND, confirm_save)],
        },
        fallbacks=[CommandHandler('cancel', cancel)]
    )

    edit_conv_handler = ConversationHandler(
        entry_points=[CommandHandler('edit_product', edit_product_start)],
        states={
            EDIT_SEARCH: [MessageHandler(filters.TEXT & ~filters.COMMAND, edit_search)],
            EDIT_SELECT: [MessageHandler(filters.TEXT & ~filters.COMMAND, edit_select)],
            EDIT_FIELD: [MessageHandler(filters.TEXT & ~filters.COMMAND, edit_field)],
            EDIT_VALUE: [MessageHandler(filters.TEXT & ~filters.COMMAND, edit_value)],
        },
        fallbacks=[CommandHandler('cancel', cancel)]
    )

    delete_conv_handler = ConversationHandler(
        entry_points=[CommandHandler('delete_product', delete_product_start)],
        states={
            DEL_SEARCH: [MessageHandler(filters.TEXT & ~filters.COMMAND, delete_search)],
            DEL_SELECT: [MessageHandler(filters.TEXT & ~filters.COMMAND, delete_select)],
            DEL_CONFIRM: [MessageHandler(filters.TEXT & ~filters.COMMAND, delete_confirm)],
        },
        fallbacks=[CommandHandler('cancel', cancel)]
    )

    app.add_handler(CommandHandler('start', start))
    app.add_handler(conv_handler)
    app.add_handler(edit_conv_handler)
    app.add_handler(delete_conv_handler)
    app.add_handler(CommandHandler('stats', get_stats))

    # إضافة مستمع للرسائل النصية العادية (لروابط أمازون)
    app.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle_direct_messages))

    print("🤖 البوت يعمل الآن! اذهب إلى تليجرام وابدأ المحادثة...")
    app.run_polling()

if __name__ == '__main__':
    main()