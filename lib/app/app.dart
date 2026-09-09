import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/localization/app_localizations.dart';
import '../core/localization/locale_controller.dart';
import '../core/notifications/push_notification_service.dart';
import '../core/widgets/loading_indicator.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/auth/presentation/providers/auth_provider.dart';
import '../features/caregiver/presentation/pages/caregiver_home_page.dart';
import '../features/messages/presentation/pages/chat_page.dart';
import '../features/onboarding/presentation/pages/language_selection_page.dart';
import '../features/patient/presentation/pages/voice_messages_page.dart';
import '../shared/root_shell.dart';
import 'theme/app_theme.dart';

class DawaCareApp extends StatefulWidget { const DawaCareApp({super.key}); @override State<DawaCareApp> createState()=>_DawaCareAppState(); }
class _DawaCareAppState extends State<DawaCareApp>{
 static const _pendingEmailConfirmationKey='dawacare_pending_email_confirmation';
 StreamSubscription<String>? _voiceSubscription,_notificationSubscription,_chatSubscription;
 StreamSubscription<AuthState>? _authSubscription;
 String? _pendingVoiceMessageId,_pendingCaregiverAlertId,_pendingChatMessageId;
 String? _lastOpenedVoiceMessageId,_lastOpenedCaregiverAlertId,_lastOpenedChatMessageId;
 @override void initState(){super.initState();final push=PushNotificationService.instance;_pendingVoiceMessageId=push.takePendingVoiceMessageId();_pendingCaregiverAlertId=push.takePendingCaregiverAlertId();_pendingChatMessageId=push.takePendingChatMessageId();_voiceSubscription=push.voiceMessageOpened.listen((id){_pendingVoiceMessageId=id;_tryOpenVoiceMessage();});_notificationSubscription=push.notificationOpened.listen((id){_pendingCaregiverAlertId=id;_tryOpenCaregiverAlert();});_chatSubscription=push.chatMessageOpened.listen((id){_pendingChatMessageId=id;_tryOpenChatMessage();});_authSubscription=Supabase.instance.client.auth.onAuthStateChange.listen((state)async{if(state.event!=AuthChangeEvent.signedIn||state.session==null)return;final prefs=await SharedPreferences.getInstance();if(prefs.getBool(_pendingEmailConfirmationKey)!=true)return;await prefs.remove(_pendingEmailConfirmationKey);WidgetsBinding.instance.addPostFrameCallback((_){if(mounted)ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(content:Text('تم تأكيد البريد الإلكتروني بنجاح وإضافة حسابك في دواء كير.')));});});WidgetsBinding.instance.addPostFrameCallback((_){_tryOpenVoiceMessage();_tryOpenCaregiverAlert();_tryOpenChatMessage();});}
 @override void dispose(){_voiceSubscription?.cancel();_notificationSubscription?.cancel();_chatSubscription?.cancel();_authSubscription?.cancel();super.dispose();}
 bool get _ready{final auth=context.read<AuthProvider>();return mounted&&auth.status==AuthStatus.signedIn&&auth.profile!=null;}
 void _tryOpenVoiceMessage(){if(!_ready||_pendingVoiceMessageId==null)return;final id=_pendingVoiceMessageId!;if(_lastOpenedVoiceMessageId==id){_pendingVoiceMessageId=null;return;}_lastOpenedVoiceMessageId=id;_pendingVoiceMessageId=null;WidgetsBinding.instance.addPostFrameCallback((_){if(mounted)Navigator.of(context).push(MaterialPageRoute(builder:(_)=>VoiceMessagesPage(initialMessageId:id)));});}
 void _tryOpenCaregiverAlert(){if(!_ready||_pendingCaregiverAlertId==null)return;final id=_pendingCaregiverAlertId!;if(_lastOpenedCaregiverAlertId==id){_pendingCaregiverAlertId=null;return;}_lastOpenedCaregiverAlertId=id;_pendingCaregiverAlertId=null;WidgetsBinding.instance.addPostFrameCallback((_){if(mounted)Navigator.of(context).push(MaterialPageRoute(builder:(_)=>CaregiverHomePage(initialAlertId:id)));});}
 Future<void> _tryOpenChatMessage() async {if(!_ready||_pendingChatMessageId==null)return;final id=_pendingChatMessageId!;if(_lastOpenedChatMessageId==id){_pendingChatMessageId=null;return;}final row=await Supabase.instance.client.from('messages').select('patient_id,sender_id,recipient_id').eq('id',id).maybeSingle();if(row==null||!mounted)return;final me=Supabase.instance.client.auth.currentUser?.id;if(me==null)return;final otherId=(row['sender_id']==me?row['recipient_id']:row['sender_id']) as String;final patientId=row['patient_id'] as String;final profile=await Supabase.instance.client.from('profiles').select('full_name').eq('id',otherId).maybeSingle();if(!mounted)return;_lastOpenedChatMessageId=id;_pendingChatMessageId=null;Navigator.of(context).push(MaterialPageRoute(builder:(_)=>ChatPage(patientId:patientId,otherUserId:otherId,otherName:(profile?['full_name'] as String?)??'مستخدم')));}
 @override Widget build(BuildContext context){final lc=context.watch<LocaleController>();final locale=Locale(lc.languageCode??'ar');return MaterialApp(title:'DawaCare',debugShowCheckedModeBanner:false,scaffoldMessengerKey:GlobalKey<ScaffoldMessengerState>(),theme:AppTheme.light,darkTheme:AppTheme.dark,themeMode:ThemeMode.system,locale:locale,supportedLocales:AppLocalizations.supportedLocales,localizationsDelegates:const[AppLocalizations.delegate,GlobalMaterialLocalizations.delegate,GlobalWidgetsLocalizations.delegate,GlobalCupertinoLocalizations.delegate],builder:(context,child){final direction=Localizations.localeOf(context).languageCode=='ar'?TextDirection.rtl:TextDirection.ltr;return Directionality(textDirection:direction,child:child!);},home:_AuthGate(onReady:(){_tryOpenVoiceMessage();_tryOpenCaregiverAlert();_tryOpenChatMessage();}) );}
}
class _AuthGate extends StatelessWidget{const _AuthGate({required this.onReady});final VoidCallback onReady;@override Widget build(BuildContext context){final locale=context.watch<LocaleController>();if(!locale.isLoaded)return const Scaffold(body:LoadingIndicator());if(locale.languageCode==null)return const LanguageSelectionPage();final auth=context.watch<AuthProvider>();WidgetsBinding.instance.addPostFrameCallback((_)=>onReady());switch(auth.status){case AuthStatus.unknown:return const Scaffold(body:LoadingIndicator());case AuthStatus.signedOut:return const LoginPage();case AuthStatus.signedIn:if(auth.profile==null)return const Scaffold(body:LoadingIndicator());return const RootShell();}}}
