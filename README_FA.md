<div dir="rtl" align="right">

# 🕳️ Black Hole 0.3.3

**Black Hole** یک رابط گرافیکی ویندوزی برای اجرای Xray و Desync است. برنامه لینک
`vless://` یا فایل JSON کامل Xray را می‌گیرد، فقط آدرس سرور را با Gray IP جایگزین
می‌کند، و مقدارهای واقعی `SNI`، هدر `Host` و مسیر اتصال را دست‌نخورده نگه می‌دارد.

> ⚠️ این ابزار برای استفادهٔ شخصی، آموزشی و شبکه‌هایی است که اجازهٔ استفاده از آن را
> داری. اجرای برنامه به دسترسی Administrator نیاز دارد، چون برای پردازش بسته‌ها از
> ابزارهای سطح سیستم استفاده می‌کند.

## ✨ امکانات اصلی

- 🧩 دریافت لینک `vless://` یا فایل JSON کامل Xray
- 🌫️ جایگزینی Gray IP فقط در مسیر `outbounds -> vnext[0] -> address`
- 🔒 حفظ `serverName`، هدر `Host`، مسیر WebSocket/XHTTP و تنظیمات واقعی TLS
- 🚀 پروفایل‌های آماده برای حالت‌های سبک، متعادل و فیلترینگ شدید
- 🎛️ تنظیم دستی Split، Fooling، BadSeq، AutoTTL، Fake SNI، Fake repeats و پورت‌ها
- 🖱️ بازشدن منوهای کشویی با کلیک روی کل کادر یا فلش
- 🪟 فعال‌سازی اختیاری Windows Proxy روی `127.0.0.1:1920`
- 💾 ذخیره و بازیابی خودکار کانفیگ، Gray IP و تنظیمات رابط


## ▶️ روش اجرای سریع

1. 📂 فایل ZIP را کامل Extract کن. برنامه را مستقیم از داخل ZIP اجرا نکن.
2. 🖱️ روی `Start-BlackHole.cmd` دوبار کلیک کن.
3. 🛡️ اگر پیام Administrator آمد، آن را تأیید کن.
4. 🔗 لینک `vless://` یا JSON کامل Xray را در بخش `Xray configuration` وارد کن.
5. ✅ دکمهٔ `Validate and import` را بزن.
6. 🌫️ در بخش `Gray IP` آدرس جدید را وارد کن.
7. 👀 دکمهٔ `Apply address and preview` را بزن و در تب `Config output` بررسی کن که فقط `address` تغییر کرده باشد.
8. 🎛️ یک `Desync profile` انتخاب کن.
9. 🚀 دکمهٔ `Start connection` را بزن.
10. 🛑 برای توقف، `Stop connection` را بزن. اگر لازم شد، از `Stop-All.cmd` استفاده کن.

## 🧭 توضیح بخش‌های صفحهٔ اصلی

| بخش | کاربرد |
|---|---|
| 🕳️ Header | نام برنامه و وضعیت کلی را نشان می‌دهد. |
| 🔴 Status badge | وضعیت فعلی را نشان می‌دهد: `Stopped`، `Starting` یا `Connected`. |
| 🧩 `1) Xray configuration` | محل واردکردن لینک VLESS یا JSON کامل Xray. |
| 🌫️ `2) Gray IP` | نمایش آدرس اصلی و جایگزینی آن با Gray IP جدید. |
| 🎛️ `3) Desync profile` | انتخاب پروفایل آماده یا حالت Custom. |
| 🪟 `Set Windows proxy...` | اگر فعال باشد، Proxy ویندوز را خودکار روی HTTP داخلی برنامه می‌گذارد. |
| 🚀 `Start connection` | اجرای Xray و Desync با تنظیمات فعلی. |
| 🛑 `Stop connection` | توقف اتصال و بازگردانی وضعیت سیستم. |

## 🔘 دکمه‌ها و گزینه‌های اصلی

| گزینه | توضیح |
|---|---|
| `Validate and import` | کانفیگ را بررسی و اطلاعات آدرس، پورت، SNI، Host و نوع شبکه را استخراج می‌کند. |
| `Open JSON` | فایل JSON آمادهٔ Xray را از سیستم انتخاب و وارد می‌کند. |
| `Apply address and preview` | Gray IP را فقط روی فیلد `address` اعمال می‌کند و پیش‌نمایش می‌سازد. |
| `Start connection` | ابتدا کانفیگ را آماده می‌کند، سپس Desync و Xray را اجرا می‌کند. |
| `Stop connection` | پردازش‌های همین برنامه را متوقف می‌کند و Proxy قبلی را برمی‌گرداند. |
| `Save config.json` | کانفیگ نهایی را به‌صورت فایل JSON ذخیره می‌کند. |
| `Preview Desync command` | فرمان winws2/Desync را قبل از اجرا نشان می‌دهد. |
| `Open log folder` | پوشهٔ لاگ‌ها و فایل‌های runtime را باز می‌کند. |

## 🧪 پروفایل‌های Desync

| پروفایل | توضیح ساده | مناسب برای |
|---|---|---|
| `Off (normal connection)` | فقط Xray اجرا می‌شود و Desync خاموش است. | تست پایه و مقایسه |
| `Speed - Light split` | Split سبک بدون Fake packet. | سرعت بیشتر و فشار کمتر |
| `Balanced - BadSeq` | یک Fake TLS با BadSeq و Split متعادل. | استفادهٔ روزمره |
| `Severe filtering - BadSeq` | حالت شدیدتر با `multidisorder` و دو Fake packet. | فیلترینگ سنگین‌تر |
| `SNI spoof - WrongSeq` | Fake SNI کنترل‌شده با `hcaptcha.com` و BadSeq قوی‌تر. | تست SNI spoof بدون تغییر SNI واقعی |
| `Severe filtering - AutoTTL` | Fake packet با AutoTTL و split شدیدتر. | مسیرهایی که TTL روی آن‌ها مؤثر است |
| `Custom` | برنامه از مقدارهای تب Advanced settings استفاده می‌کند. | تست دستی و دقیق |

## ⚙️ توضیح گزینه‌های Advanced settings

| گزینه | معنی | نکته |
|---|---|---|
| `Split method` | روش شکستن TLS ClientHello. | مقدارهای مجاز: `multisplit` یا `multidisorder` |
| `Split positions` | نقطه‌های split داخل بسته. | نمونه‌ها: `midsld`، `1,midsld`، `1,sniext+1,midsld` |
| `Method preventing Fake delivery to server` | روش جلوگیری از رسیدن Fake packet به مقصد واقعی. | مقدارها: `none`، `badseq`، `ttl`، `badsum`، `md5sig` |
| `Bad Sequence Increment` | مقدار sequence اشتباه برای Fake packet. | فقط وقتی `Fooling = badseq` فعال است. |
| `Optional Fake SNI` | SNI جعلی فقط برای Fake packet. | خالی یعنی random SNI؛ SNI/Host واقعی کانفیگ تغییر نمی‌کند. |
| `AutoTTL Delta` | اختلاف TTL در حالت AutoTTL. | فقط وقتی `Fooling = ttl` فعال است. |
| `AutoTTL Min` | حداقل TTL مجاز. | باید از `AutoTTL Max` بیشتر نباشد. |
| `AutoTTL Max` | حداکثر TTL مجاز. | باید از `AutoTTL Min` کمتر نباشد. |
| `Fake repeats` | تعداد تکرار Fake packet. | فقط وقتی Fooling خاموش نباشد استفاده می‌شود. |
| `SOCKS Port` | پورت SOCKS داخلی Xray. | پیش‌فرض: `1819` |
| `HTTP Port` | پورت HTTP داخلی Xray و Windows Proxy. | پیش‌فرض: `1920` |

## 📑 توضیح تب‌ها

| تب | کاربرد |
|---|---|
| `Status` | نمایش اطلاعات کانفیگ واردشده: Address، Port، SNI، Host، Network و Security. |
| `Advanced settings` | تنظیم دستی تمام گزینه‌های Desync و پورت‌ها. |
| `Config output` | نمایش کانفیگ نهایی بعد از اعمال Gray IP. |
| `Log` | نمایش رخدادهای برنامه، خطاها، مسیر فایل‌ها و وضعیت اجرا. |

## 🌐 پورت‌ها و Proxy

```text
SOCKS: 0.0.0.0:1819
HTTP:  0.0.0.0:1920
Windows system proxy: 127.0.0.1:1920
```

اگر گزینهٔ Windows Proxy روشن باشد، بیشتر برنامه‌هایی که از Proxy سیستم استفاده
می‌کنند از مسیر `127.0.0.1:1920` عبور می‌کنند.

## 🧯 توقف اضطراری

اگر پنجره بسته شد ولی اتصال یا Proxy باقی ماند:

1. 🛑 فایل `Stop-All.cmd` را اجرا کن.
2. 🔁 برنامه فقط پردازش‌هایی را می‌بندد که خودش ثبت کرده است.
3. 🪟 Proxy قبلی ویندوز تا حد امکان بازگردانی می‌شود.

## 🔐 حریم خصوصی و فایل‌های ذخیره‌شده

- 🔒 کانفیگ، UUID، Gray IP و تنظیمات فقط در پوشهٔ همین برنامه ذخیره می‌شوند.
- 💾 فایل‌های ماندگار اصلی: `runtime/saved-workspace.json` و `runtime/user-settings.json`
- 🧹 فایل‌های موقت اتصال بعد از توقف حذف می‌شوند.
- 📁 لاگ‌ها در پوشهٔ `runtime` قرار می‌گیرند.

## 🛠️ رفع مشکل‌های رایج

| مشکل | راه‌حل |
|---|---|
| برنامه باز نمی‌شود | اول ZIP را Extract کن، بعد `Start-BlackHole.cmd` را اجرا کن. |
| پیام Administrator می‌آید | طبیعی است؛ برای WinDivert و پردازش بسته‌ها لازم است. |
| فایل core پیدا نمی‌شود | مطمئن شو کل پوشه Extract شده و آنتی‌ویروس فایلی را حذف نکرده است. |
| Proxy بعد از بستن برنامه باقی مانده | `Stop-All.cmd` را اجرا کن. |
| اتصال شروع نمی‌شود | تب `Log` و فایل‌های داخل `runtime` را بررسی کن. |
| Gray IP قبول نمی‌شود | باید IPv4 یا IPv6 مستقیم باشد، نه دامنه مثل `example.com`. |

## 👤 سازنده

ساخته شده توسط ReZa Kh