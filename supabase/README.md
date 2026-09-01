# DawaCare — Supabase setup

## ✅ حالة هذا المشروع: مُهيّأ بالفعل
تم إنشاء وتجهيز مشروع Supabase التالي عبر MCP مباشرة — لا حاجة لإعادة الخطوات
1-4 أدناه إلا إذا أنشأت مشروعًا جديدًا بنفسك:

| العنصر | القيمة |
|---|---|
| Project ref | `lwdwlfhytdetziqfbgje` |
| المنطقة | `eu-west-3` (باريس) |
| Project URL | `https://lwdwlfhytdetziqfbgje.supabase.co` |
| الجداول | تم تطبيق `schema.sql` كاملاً (10 جداول + RLS + الدوال) ✅ |
| Edge Function | `escalation-check` منشورة ونشطة (ACTIVE) ✅ |
| pg_cron | `dawacare-escalation-check` كل 10 دقائق — تم اختباره ويرجع `200 OK` ✅ |
| Dashboard | https://supabase.com/dashboard/project/lwdwlfhytdetziqfbgje |

القيم أعلاه مضبوطة كافتراضيات في `lib/core/config/supabase_config.dart`،
فـ `flutter run` يشتغل مباشرة بلا `--dart-define`. الكود الخاص بتسجيل جهاز
push (`PushRegistrationService`) وقناة إشعارات المرافقين مضافان بالفعل فـ
التطبيق — الخطوة المتبقية هي **القسم 5 أدناه**: خطوات يدوية فـ Firebase
Console (لا يوجد لها أداة MCP) لتفعيل push حقيقي، وإلا فالتطبيق يشتغل كاملاً
بدونها (المرافق يشوف التنبيه فـ التطبيق فقط، بلا إشعار push على الهاتف).

> ملاحظة أمان: لم أُدخل الـ `service_role` key في أي مكان — الاتصال بـ MCP
> لا يكشفه لي أصلاً. جدولة pg_cron تستعمل الـ anon key فقط للمرور من فحص
> JWT الخاص بالـ Edge Function؛ الدالة نفسها تحصل على `service_role` من
> متغيرات البيئة التي توفرها Supabase تلقائيًا لكل Edge Function.

---

## 1. إنشاء مشروع جديد (فقط إذا بدأت من الصفر)
Create a new Supabase project (pick a region close to Morocco, e.g. `eu-west-3` /
Paris, for lower latency). Grab the **Project URL** and the **anon / publishable
key** from *Project Settings → API* — you'll need them in `lib/core/config/supabase_config.dart`.

## 2. Apply the schema
Open the SQL editor in the Supabase dashboard and run `schema.sql` from this
folder (or, with the Supabase CLI: `supabase db push` after `supabase link`).

This creates all tables, the `handle_new_user` trigger (auto-creates a
`profiles` row + unique 6-character family code on signup), RLS policies, and
adds `dose_instances` / `caregiver_alerts` to the Realtime publication.

## 3. Deploy the escalation Edge Function
```bash
supabase functions deploy escalation-check --no-verify-jwt
```
This function catches doses the patient never confirmed and turns them into
caregiver alerts. It works with **no extra configuration** for in-app alerts
(the `caregiver_alerts` table + Realtime is enough for the Family tab to show
"missed dose" notices). Push notifications are optional — see step 5.

## 4. Schedule it with pg_cron
In the SQL editor:
```sql
create extension if not exists pg_cron;

select cron.schedule(
  'dawacare-escalation-check',
  '*/10 * * * *',  -- every 10 minutes
  $$
  select net.http_post(
    url := 'https://<YOUR_PROJECT_REF>.supabase.co/functions/v1/escalation-check',
    headers := jsonb_build_object('Authorization', 'Bearer <YOUR_SERVICE_ROLE_KEY>')
  );
  $$
);
```
(`pg_net` ships enabled by default on Supabase; if `net.http_post` is missing,
enable the `pg_net` extension first.)

## 5. (اختياري) تفعيل push حقيقي لتنبيهات العائلة

**الكود جاهز بالكامل** على الطرفين — الـEdge Function ترسل عبر FCM HTTP v1
(OAuth2 عبر service account، وليس الـlegacy API المتوقف)، والتطبيق يسجّل
رمز الجهاز (FCM token) في جدول `devices` تلقائيًا عند تسجيل الدخول، ويعرض
تنبيهًا حتى لو كان التطبيق مفتوحًا (قناة إشعارات منفصلة `caregiver_alerts`).
**ما تبقى فهو خطوات يدوية في Firebase Console** لا يوجد لها أداة MCP
(لا Firebase MCP connector متاح، ولا أداة لضبط أسرار Edge Functions من هنا):

1. أنشئ مشروع Firebase (أو استعمل موجودًا) بنفس الـpackage name:
   `com.comptaflow.dawacare` — من [console.firebase.google.com](https://console.firebase.google.com).
2. أضف تطبيق Android داخل المشروع بنفس الـpackage name، ونزّل
   `google-services.json`، وضعه في `android/app/google-services.json`.
3. فعّل الـplugin فـ Gradle (بعد `flutter create`):
   - فـ `android/build.gradle.kts` (المستوى الجذري)، داخل `buildscript.dependencies`:
     ```kotlin
     classpath("com.google.gms:google-services:4.4.2")
     ```
   - فـ `android/app/build.gradle.kts`، فوق أي شيء آخر:
     ```kotlin
     plugins {
         id("com.google.gms.google-services")
     }
     ```
   > إذا ما بغيتيش push دابا، تخطى هاد الخطوة والخطوات التالية — التطبيق
   > كيخدم بشكل طبيعي بلا Firebase (التذكيرات المحلية ماشي متأثرة).
4. Firebase Console → Project settings → Service accounts → **Generate new
   private key** (ملف JSON). هذا خاص بالـEdge Function باش تقدر تبعث push
   (منفصل تمامًا عن `google-services.json`).
5. عرّف السر فـ Supabase — بطريقتين، اختر الأسهل بالنسبة لك:
   - **عبر Dashboard** (بلا CLI): Project → Edge Functions → `escalation-check`
     → Secrets → أضف `FCM_SERVICE_ACCOUNT_JSON` والصق محتوى ملف الـJSON كاملاً.
   - **عبر CLI**:
     ```bash
     supabase secrets set FCM_SERVICE_ACCOUNT_JSON="$(cat service-account.json)" \
       --project-ref lwdwlfhytdetziqfbgje
     ```
6. أعد تشغيل التطبيق بعد `flutter pub get` (أضفت `firebase_core` و
   `firebase_messaging` للمشروع). عند تسجيل الدخول، يسجَّل رمز الجهاز
   تلقائيًا فـ `devices` — جرّب: خلّي جرعة تفوت موعدها بأكثر من مهلة
   `grace_period_min`، وانتظر دورة الـcron التالية (كل 10 دقائق) — إذا كان
   المرافق مرتبطًا، خاصو يتلقى push حقيقي.

بدون هاد الخطوات، كل شيء آخر خدام عادي — المرافق كيشوف التنبيه فـ تبويب
العائلة (Realtime)، غير أنه ما غاديش يتلقى push على الهاتف.

## 6. Row Level Security model
- A patient can always read/write their own data.
- A caregiver only sees a patient's data after the patient (or the caregiver,
  using the patient's **family code**) creates a `caregiver_patient` link.
- `role = 'VIEWER'` can read but not edit; `'CAREGIVER'` and
  `'PRIMARY_CAREGIVER'` can edit medications/schedules on the patient's behalf.
- All policies are defined in `schema.sql` — review them before going to
  production, especially if you add new tables.
