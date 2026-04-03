@echo off
cd /d "d:\SHEYAQA_SYSTEM\02-Python_Robot"

set PYTHONIOENCODING=utf-8
echo. >> scraper_log.txt
echo ========================================== >> scraper_log.txt
echo [%date% %time%] - بدء التشغيل >> scraper_log.txt
python scraper.py >> scraper_log.txt 2>&1