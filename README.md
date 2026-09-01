# دواء كير — DawaCare

تطبيق تذكير بالأدوية للمرضى وعائلاتهم (Android، Flutter). المريض يؤكد جرعاته
بضغطة واحدة؛ العائلة تتابع الالتزام وتتلقى تنبيهًا إذا فاتت جرعة.

هذا مشروع Flutter **كامل وجاهز للتطوير**، مبنيّ على نفس ستاك المشاريع
السابقة (Flutter + Provider + Supabase + GitHub Actions)، لكنه **ليس مبنيًا
(compiled) بعد** — الخطوات أدناه تُجهّزه للتشغيل ثم للنشر على Play Store.

## لماذا لم يُبنَ مباشرة؟
بيئة التنفيذ التي أنشأت هذا المشروع لا تملك Flutter SDK ولا Android SDK
(بلا وصول لشبكة pub.dev/Google)، فلم يكن ممكنًا تشغيل `flutter create` أو
`flutter pub get` أو التحقق من الترجمة (compile) هنا. الكود مكتوب بعناية
ويتبع أنماط Flutter/Supabase الحالية، لكن راجع أول build محليًا كخطوة أولى.

---

## 1. التشغيل المحلي (أول مرة)

✅ **قاعدة البيانات جاهزة فعلاً** — أنشأت مشروع Supabase حقيقيًا عبر
الاتصال المباشر (project ref `lwdwlfhytdetziqfbgje`، منطقة `eu-west-3`)،
وطبّقت `schema.sql` كاملاً (10 جداول + RLS)، ونشرت Edge Function
`escalation-check`، وجدولتها بـ pg_cron كل 10 دقائق — اختبرتها ورجعت
`200 OK`. التفاصيل الكاملة فـ `supabase/README.md`. القيم مضبوطة مسبقًا
فـ `lib/core/config/supabase_config.dart`، فما بقاش خاصك تدير حتى شي حاجة
فـ Supabase قبل التجربة الأولى.

```bash
# 1. فك ضغط المشروع ثم داخل المجلد:
flutter create --project-name dawacare --org com.comptaflow.dawacare .
# هذا يُنشئ مجلدات android/ (و ios/ إذا أردت) دون المساس بمجلد lib/ الموجود.

# 2. التبعيات
flutter pub get

# 3. الأصول (أيقونة التطبيق)
dart run flutter_launcher_icons

# 4. تشغيل على جهاز/محاكي متصل — يشتغل مباشرة، القيم مضبوطة مسبقًا
flutter run
```

> إذا بغيتي تبدّل مشروع Supabase (مثلاً للإنتاج لاحقًا)، مرّر
> `--dart-define=SUPABASE_URL=...` و`--dart-define=SUPABASE_ANON_KEY=...`
> عند البناء، وهذا سيتجاوز القيم الافتراضية.

## 2. توقيع Android (Keystore)
```bash
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 \
  -validity 10000 -alias upload
```
احتفظ بالملف وكلمات المرور في مكان آمن (وليس في git). ثم أنشئ
`android/key.properties` (موجود مسبقًا في `.gitignore`):
```properties
storePassword=...
keyPassword=...
keyAlias=upload
storeFile=upload-keystore.jks
```
وأضف في `android/app/build.gradle.kts` (فوق `android { ... }`):
```kotlin
import java.util.Properties
import java.io.FileInputStream

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
```
وداخل `android { ... }`:
```kotlin
signingConfigs {
    create("release") {
        keyAlias = keystoreProperties["keyAlias"] as String?
        keyPassword = keystoreProperties["keyPassword"] as String?
        storeFile = keystoreProperties["storeFile"]?.let { file(it) }
        storePassword = keystoreProperties["storePassword"] as String?
    }
}
buildTypes {
    release {
        signingConfig = signingConfigs.getByName("release")
    }
}
```
وتأكد أن `defaultConfig.applicationId = "com.comptaflow.dawacare"` وأن
`minSdk = 23` (يلزم لبعض ميزات الإشعارات الدقيقة) و`targetSdk` أحدث ما هو
متاح عند البناء (راجع القسم 5 أدناه — Google تُلزم بـ API 36 ابتداءً من
31 أغسطس 2026).

### أذونات AndroidManifest المطلوبة للتذكيرات
بعد `flutter create`، أضف هذه الأسطر داخل `<manifest>` في
`android/app/src/main/AndroidManifest.xml` (فوق `<application>`)، وإلا
فالتذكيرات الدقيقة ولا تعمل بعد إعادة تشغيل الهاتف:
```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />
<uses-permission android:name="android.permission.USE_EXACT_ALARM" />
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
<uses-permission android:name="android.permission.VIBRATE" />
```
`RECEIVE_BOOT_COMPLETED` is what lets `flutter_local_notifications`'s own
boot receiver re-arm exact alarms after the phone restarts — without it,
every scheduled reminder is silently lost on reboot.

## 3. GitHub Actions — أسرار (Secrets) مطلوبة
أضف هذه في **Settings → Secrets and variables → Actions** بالمستودع:

| السر | الوصف |
|---|---|
| `KEYSTORE_BASE64` | `base64 -w0 upload-keystore.jks` (نتيجة الأمر كاملة) |
| `KEYSTORE_STORE_PASSWORD` | كلمة مرور الـ keystore |
| `KEYSTORE_KEY_PASSWORD` | كلمة مرور المفتاح |
| `KEYSTORE_KEY_ALIAS` | `upload` (أو الاسم الذي اخترته) |
| `SUPABASE_URL` | رابط مشروع Supabase (`https://lwdwlfhytdetziqfbgje.supabase.co` — نفس القيمة المضبوطة كافتراضي فـ `supabase_config.dart`) |
| `SUPABASE_ANON_KEY` | anon/publishable key (راجع نفس الملف، أو Project Settings → API فـ Dashboard) |
| `GOOGLE_SERVICES_JSON` | (اختياري) محتوى `google-services.json` كاملاً، لتفعيل push |
| `PLAY_SERVICE_ACCOUNT_JSON` | (اختياري) لنشر تلقائي عبر `workflow_dispatch` |

الـ workflow في `.github/workflows/ci-cd.yml` يقوم بـ: analyze → test →
build AAB+APK موقّعين → رفعهما كـ artifacts، مع خطوة نشر اختيارية لـ Play
Console عبر تشغيل يدوي (`workflow_dispatch`).

## 4. قائمة تحقق قبل النشر على Play Store
- [ ] **Target API level 36 (Android 16)** — إلزامي للتطبيقات الجديدة ابتداءً
      من 31 أغسطس 2026. تأكد أن `flutter build` يستخدم أحدث Android Gradle
      Plugin/compileSdk عند ذلك التاريخ.
- [ ] **Data Safety form** في Play Console: صرّح بجمع بيانات صحية
      ("Health info")، بيانات الحساب، ومعرّف الجهاز (إن فعّلت push). راجع
      `PRIVACY_POLICY.md` كمرجع لما يُجمع.
- [ ] **رابط سياسة خصوصية عام** — انشر `PRIVACY_POLICY.md` (بعد ملء
      الحقول) على رابط عام وأدرجه في Play Console.
- [ ] **أيقونة وصور المتجر**: `assets/icon/app_icon.png` جاهزة (1024×1024)؛
      تحتاج أيضًا Feature Graphic (1024×500) ولقطات شاشة — غير مُولّدة هنا.
- [ ] **إخلاء المسؤولية الطبية**: مُدرج في سياسة الخصوصية؛ فكّر في إضافته
      أيضًا كشاشة onboarding داخل التطبيق (غير موجودة في هذا السكافولد).
- [ ] **اختبار داخلي (Internal testing track)** قبل الإنتاج، خصوصًا تدفق
      الإشعارات والتذكيرات على أجهزة Android حقيقية (12/13/14+).
- [ ] **صلاحية "Exact Alarms"**: بعض أجهزة Android تتطلب تفعيلها يدويًا من
      إعدادات النظام؛ التطبيق يطلبها لكن تأكد من تجربة رفض المستخدم لها.

## 5. البنية المعمارية — وأين تختلف عن المخطط الأصلي
هذا السكافولد ينفّذ **جوهر** الدورة الموصوفة في الوثيقة الأصلية
(Medication → Schedule → Dose Instance → Reminder → Confirmation/Escalation
→ Event → Adherence)، لكن مع تبسيطات واعية لتناسب مرحلة V1 ومكدّس عملك
الحالي:

| القرار في هذا السكافولد | البديل المذكور في الوثيقة | السبب |
|---|---|---|
| Provider لإدارة الحالة | Riverpod | يطابق مكدّسك الحالي عبر جميع المشاريع |
| Supabase (Postgres + Auth + RLS + Edge Functions) | Backend NestJS منفصل | يطابق مكدّسك الحالي، ويُغني عن استضافة خادم إضافي |
| sqflite (تخزين محلي بسيط) | Drift | تعقيد أقل لنفس الحاجة الفعلية في V1 |
| تطبيق واحد بأربعة تبويبات (اليوم / أدويتي / العائلة / الإعدادات) | تطبيقان منفصلان (Patient App / Caregiver App) | معظم المستخدمين مريض ومرافق في آن؛ تطبيق واحد أبسط صيانةً |
| ربط عائلي عبر "رمز عائلة" فوري (بدون موافقة معلّقة) | نظام صلاحيات كامل (PENDING/ACCEPTED) | أسرع للاستخدام الفعلي داخل عائلة واحدة؛ يمكن إضافة الموافقة لاحقًا |
| تسجيل دخول بالبريد وكلمة المرور فقط | Phone OTP + Password | OTP يتطلب مزوّد SMS (Twilio) مدفوعًا؛ أضِفه عند الحاجة عبر Supabase Auth |

## 6. ما لم يُبنَ بعد (خارطة الطريق)
- تعديل دواء/جدول موجود (متوفر حاليًا: إضافة + إيقاف فقط)
- شاشة تقارير أسبوعية/شهرية مفصّلة للمرافق (متوفر: نسبة التزام حالية فقط)
- سجل تدقيق (Audit Log) كامل بواجهة عرض
- أدوار Doctor / Pharmacist (مذكورة في القسم 27 من الوثيقة الأصلية كخطوة V2)
- دعم iOS (المشروع Android-only حاليًا، مثل باقي تطبيقاتك)
- اختبارات Widget/Integration (مضاف حاليًا: اختبارات وحدة لـ `DoseEngine` فقط)

## 7. هيكلة المجلدات
```
lib/
  app/            MaterialApp, theming, auth gate
  core/           config, database (sqflite), notifications, network, widgets
  models/         كائنات Dart المطابقة لجداول Postgres
  features/
    auth/         تسجيل الدخول/حساب جديد
    medications/  إضافة/عرض الأدوية والجداول
    doses/        DoseEngine + DoseRepository + DoseProvider (قلب التطبيق)
    reminders/    NotificationService + ReminderEngine + ReminderPolicy
    sync/         SyncEngine (طابور offline)
    caregiver/    تبويب العائلة، الربط، نسبة الالتزام
    patient/      شاشة "اليوم"
    settings/     الملف الشخصي، رمز العائلة، إعدادات التذكير
  shared/         RootShell (bottom nav)
supabase/
  schema.sql                     جداول + RLS + دوال
  functions/escalation-check/    Edge Function لتنبيه العائلة عند تفويت جرعة
  README.md                      خطوات الإعداد كاملة
.github/workflows/ci-cd.yml      Build + Sign + (نشر اختياري)
```
