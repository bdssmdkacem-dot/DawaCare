import 'package:flutter/material.dart';

class AppLocalizations {
  const AppLocalizations(this.locale);
  final Locale locale;
  static const supportedLocales = [Locale('ar'), Locale('en'), Locale('fr')];
  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();
  static AppLocalizations of(BuildContext context) => Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  bool get isArabic => locale.languageCode == 'ar';
  String _tr(String ar, String en, String fr) => switch (locale.languageCode) { 'en' => en, 'fr' => fr, _ => ar };
  String get appName => _tr('دواء كير', 'DawaCare', 'DawaCare');
  String get tagline => _tr('ما تنساش دوا حتى مرة', 'Never miss your medicine', 'N’oubliez plus vos médicaments');
  String get chooseLanguage => _tr('اختر لغتك', 'Choose your language', 'Choisissez votre langue');
  String get continueLabel => _tr('متابعة', 'Continue', 'Continuer');
  String get login => _tr('تسجيل الدخول', 'Sign in', 'Se connecter');
  String get register => _tr('إنشاء حساب', 'Create an account', 'Créer un compte');
  String get email => _tr('البريد الإلكتروني', 'Email', 'E-mail');
  String get password => _tr('كلمة المرور', 'Password', 'Mot de passe');
  String get fullName => _tr('الاسم الكامل', 'Full name', 'Nom complet');
  String get newAccountQuestion => _tr('ماعندكش حساب؟ سجل الآن', 'Don’t have an account? Create one', 'Vous n’avez pas de compte ? Créez-en un');
  String get today => _tr('اليوم', 'Today', 'Aujourd’hui');
  String get medicines => _tr('أدويتي', 'My medicines', 'Mes médicaments');
  String get family => _tr('العائلة', 'Family', 'Famille');
  String get settings => _tr('الإعدادات', 'Settings', 'Paramètres');
  String get invalidEmail => _tr('أدخل بريدًا إلكترونيًا صحيحًا', 'Enter a valid email address', 'Saisissez une adresse e-mail valide');
  String get passwordMin => _tr('6 أحرف على الأقل', 'At least 6 characters', '6 caractères minimum');
  String get enterName => _tr('أدخل اسمك', 'Enter your name', 'Saisissez votre nom');
  String get accountCreated => _tr('تم إنشاء الحساب بنجاح!', 'Account created successfully!', 'Compte créé avec succès !');
  String get unexpectedError => _tr('حدث خطأ غير متوقع. حاول مرة أخرى.', 'Something went wrong. Please try again.', 'Une erreur est survenue. Réessayez.');
  String get followUpMessages => _tr('رسائل المتابعة', 'Care messages', 'Messages de suivi');
  String get followUpMessagesSubtitle => _tr('استمع إلى الرسائل الصوتية من متابعيك', 'Listen to voice messages from your caregivers', 'Écoutez les messages vocaux de vos accompagnants');
  String get noScheduledMedicines => _tr('لا توجد أدوية مجدولة اليوم', 'No medicines scheduled today', 'Aucun médicament prévu aujourd’hui');
  String get addFirstMedicine => _tr('أضف دواءك الأول من تبويب "أدويتي"', 'Add your first medicine from "My medicines"', 'Ajoutez votre premier médicament depuis « Mes médicaments »');
  String get pullToRetry => _tr('اسحب للأسفل للمحاولة مرة أخرى', 'Pull down to try again', 'Tirez vers le bas pour réessayer');
  String get skipDoseTitle => _tr('تخطي هذه الجرعة؟', 'Skip this dose?', 'Ignorer cette dose ?');
  String skippedDose(String name) => _tr('سيتم تسجيل $name كـ"متخطاة" لهذه المرة.', '$name will be recorded as skipped this time.', '$name sera enregistré comme dose ignorée cette fois.');
  String get cancel => _tr('إلغاء', 'Cancel', 'Annuler');
  String get skip => _tr('تخطي', 'Skip', 'Ignorer');
  String get newMedicine => _tr('دواء جديد', 'New medicine', 'Nouveau médicament');
  String get cameraMedicine => _tr('تصوير الدواء بالكاميرا', 'Take a photo of the medicine', 'Photographier le médicament');
  String get galleryMedicine => _tr('اختيار صورة من الهاتف', 'Choose a photo from your phone', 'Choisir une photo du téléphone');
  String get removeMedicineImageTitle => _tr('حذف صورة الدواء؟', 'Delete medicine photo?', 'Supprimer la photo du médicament ?');
  String get removeMedicineImageBody => _tr('سيبقى الدواء والجرعات كما هي، وستُحذف الصورة فقط.', 'The medicine and doses will remain unchanged; only the photo will be deleted.', 'Le médicament et les doses resteront inchangés ; seule la photo sera supprimée.');
  String get deleteImage => _tr('حذف الصورة', 'Delete photo', 'Supprimer la photo');
  String get changeMedicineImage => _tr('تغيير صورة الدواء', 'Change medicine photo', 'Changer la photo');
  String get deleteMedicineImage => _tr('حذف صورة الدواء', 'Delete medicine photo', 'Supprimer la photo du médicament');
  String get deactivateMedicine => _tr('إيقاف الدواء', 'Stop medicine', 'Arrêter le médicament');
  String get noMedicinesYet => _tr('لم تُضِف أي دواء بعد', 'No medicines added yet', 'Aucun médicament ajouté');
  String get addMedicineHint => _tr('اضغط على "دواء جديد" لإضافة أول دواء وتحديد موعده', 'Tap "New medicine" to add your first medicine and schedule it', 'Appuyez sur « Nouveau médicament » pour ajouter votre premier médicament et le planifier');
  String get deactivateMedicineTitle => _tr('إيقاف هذا الدواء؟', 'Stop this medicine?', 'Arrêter ce médicament ?');
  String deactivateMedicineBody(String name) => _tr('لن تُنشأ جرعات جديدة لـ$name. يمكنك إضافته من جديد لاحقًا.', 'No new doses will be created for $name. You can add it again later.', 'Aucune nouvelle dose ne sera créée pour $name. Vous pourrez l’ajouter à nouveau plus tard.');
  String get stop => _tr('إيقاف', 'Stop', 'Arrêter');
  String get addMedicinePhoto => _tr('أضف صورة الدواء', 'Add a medicine photo', 'Ajouter une photo du médicament');
  String get addMedicinePhotoHint => _tr('صوّر العلبة لتسهيل التعرّف على الدواء', 'Photograph the package to make the medicine easier to identify', 'Photographiez la boîte pour faciliter l’identification');
  String get medicineName => _tr('اسم الدواء *', 'Medicine name *', 'Nom du médicament *');
  String get enterMedicineName => _tr('أدخل اسم الدواء', 'Enter the medicine name', 'Saisissez le nom du médicament');
  String get strength => _tr('التركيز (مثال: 500 ملغ)', 'Strength (e.g. 500 mg)', 'Dosage (ex. 500 mg)');
  String get dosageForm => _tr('الشكل', 'Form', 'Forme');
  String get doseAmount => _tr('الكمية في كل جرعة (مثال: قرص واحد)', 'Amount per dose (e.g. one tablet)', 'Quantité par dose (ex. un comprimé)');
  String get instructionsOptional => _tr('تعليمات (اختياري)', 'Instructions (optional)', 'Instructions (facultatif)');
  String get frequency => _tr('التكرار', 'Frequency', 'Fréquence');
  String get daily => _tr('يوميًا', 'Daily', 'Tous les jours');
  String get specificDays => _tr('أيام محددة', 'Specific days', 'Jours précis');
  String get everyFewDays => _tr('كل عدة أيام', 'Every few days', 'Tous les quelques jours');
  String get once => _tr('مرة واحدة', 'Once', 'Une fois');
  String get asNeeded => _tr('عند الحاجة', 'As needed', 'Si nécessaire');
  String get chooseAtLeastOneDay => _tr('اختر يومًا واحدًا على الأقل', 'Choose at least one day', 'Choisissez au moins un jour');
  String get everyHowManyDays => _tr('كل كم يوم؟', 'Every how many days?', 'Tous les combien de jours ?');
  String get doseTime => _tr('وقت الجرعة', 'Dose time', 'Heure de la dose');
  String get startDate => _tr('تاريخ البدء', 'Start date', 'Date de début');
  String get endDateOptional => _tr('تاريخ الانتهاء (اختياري)', 'End date (optional)', 'Date de fin (facultatif)');
  String get saveMedicine => _tr('حفظ الدواء', 'Save medicine', 'Enregistrer le médicament');
  String dosageFormLabel(String value) => switch (value) {
        'قرص' => _tr('قرص', 'Tablet', 'Comprimé'),
        'كبسولة' => _tr('كبسولة', 'Capsule', 'Gélule'),
        'شراب' => _tr('شراب', 'Syrup', 'Sirop'),
        'حقنة' => _tr('حقنة', 'Injection', 'Injection'),
        'قطرة' => _tr('قطرة', 'Drops', 'Gouttes'),
        _ => _tr('أخرى', 'Other', 'Autre'),
      };
  String weekdayLabel(int day) => switch (day) {
        1 => _tr('الإثنين', 'Monday', 'Lundi'), 2 => _tr('الثلاثاء', 'Tuesday', 'Mardi'), 3 => _tr('الأربعاء', 'Wednesday', 'Mercredi'),
        4 => _tr('الخميس', 'Thursday', 'Jeudi'), 5 => _tr('الجمعة', 'Friday', 'Vendredi'), 6 => _tr('السبت', 'Saturday', 'Samedi'), 7 => _tr('الأحد', 'Sunday', 'Dimanche'), _ => '',
      };
  String get enableReminderNotifications => _tr('تفعيل إشعارات التذكير', 'Enable reminder notifications', 'Activer les notifications de rappel');
  String get reminderNotificationsRequired => _tr('مطلوب لتصلك تذكيرات موعد الدواء', 'Required to receive medicine reminders', 'Nécessaire pour recevoir les rappels de médicaments');
  String get notificationPermissionRequested => _tr('تم طلب أذونات الإشعارات', 'Notification permission requested', 'Autorisation des notifications demandée');
  String get logout => _tr('تسجيل الخروج', 'Sign out', 'Se déconnecter');
  String get language => _tr('اللغة', 'Language', 'Langue');
  String get arabic => 'العربية'; String get english => 'English'; String get french => 'Français';
  String get familyRequests => _tr('طلبات بانتظار موافقتك', 'Requests awaiting your approval', 'Demandes en attente de votre approbation');
  String get inviteToMedicines => _tr('دعوة فرد لأدويتي', 'Invite someone to my medicines', 'Inviter quelqu’un à mes médicaments');
  String get followSomeone => _tr('متابعة شخص آخر', 'Follow someone', 'Suivre quelqu’un');
  String get pendingRequests => _tr('طلباتي المعلّقة', 'My pending requests', 'Mes demandes en attente');
  String get alerts => _tr('تنبيهات', 'Alerts', 'Alertes');
  String get familyMembers => _tr('أفراد العائلة', 'Family members', 'Membres de la famille');
  String get noFamilyLinked => _tr('لم تربط أي فرد من العائلة بعد', 'No family member linked yet', 'Aucun membre de la famille lié');
  String get requestFollowNow => _tr('طلب متابعة أحد الآن', 'Request to follow someone now', 'Demander à suivre quelqu’un');
  String get accept => _tr('قبول', 'Accept', 'Accepter'); String get reject => _tr('رفض', 'Reject', 'Refuser');
  String get waitingApproval => _tr('بانتظار الموافقة', 'Awaiting approval', 'En attente d’approbation');
  String get removeLink => _tr('إزالة الربط', 'Remove link', 'Supprimer le lien');
  String get removeLinkTitle => _tr('إزالة الربط؟', 'Remove link?', 'Supprimer le lien ?');
  String removeLinkBody(String name) => _tr('لن تتمكن بعد الآن من متابعة أدوية $name.', 'You will no longer be able to follow $name’s medicines.', 'Vous ne pourrez plus suivre les médicaments de $name.');
  String get sendGeneralVoice => _tr('إرسال رسالة صوتية عامة', 'Send a general voice message', 'Envoyer un message vocal général');
  String get voiceMessagesEmpty => _tr('لا توجد رسائل صوتية بعد', 'No voice messages yet', 'Aucun message vocal pour le moment');
  String get linkedDoseMessage => _tr('رسالة مرتبطة بجرعة', 'Message linked to a dose', 'Message lié à une dose');
  String doseLabel(String value) => _tr('الجرعة: $value', 'Dose: $value', 'Dose : $value');
  String doseTimeLabel(String value) => _tr('وقت الجرعة: $value', 'Dose time: $value', 'Heure de la dose : $value');
  String listenLabel(int count) => _tr('الاستماع $count/2', 'Listens $count/2', 'Écoutes $count/2');
  String get voicePlaybackError => _tr('تعذّر تشغيل الرسالة الصوتية.', 'Could not play the voice message.', 'Impossible de lire le message vocal.');
  String get voiceDeletedAfterTwoListens => _tr('تم الاستماع للرسالة مرتين وتم حذفها بأمان.', 'The message was listened to twice and safely deleted.', 'Le message a été écouté deux fois puis supprimé en toute sécurité.');
  String get voiceListenUpdateError => _tr('اكتمل التشغيل، لكن تعذّر تحديث عداد الاستماع.', 'Playback finished, but the listen count could not be updated.', 'La lecture est terminée, mais le compteur d’écoutes n’a pas pu être mis à jour.');
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();
  @override bool isSupported(Locale locale) => ['ar', 'en', 'fr'].contains(locale.languageCode);
  @override Future<AppLocalizations> load(Locale locale) async => AppLocalizations(locale);
  @override bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) => false;
}
