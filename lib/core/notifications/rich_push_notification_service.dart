import 'dart:async';
import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';

class RichPushNotificationService {
  RichPushNotificationService._(); static final instance=RichPushNotificationService._();
  final _plugin=FlutterLocalNotificationsPlugin(); bool _initialized=false; final _messageController=StreamController<String>.broadcast();
  Stream<String> get messageOpened=>_messageController.stream;
  static const _channelId='caregiver_alerts';
  Future<void> init() async {if(_initialized)return;const settings=InitializationSettings(android:AndroidInitializationSettings('@mipmap/ic_launcher'));await _plugin.initialize(settings,onDidReceiveNotificationResponse:(r){final p=r.payload;if(p!=null&&p.startsWith('CHAT_MESSAGE:'))_messageController.add(p.substring('CHAT_MESSAGE:'.length));});final android=_plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();await android?.createNotificationChannel(const AndroidNotificationChannel(_channelId,'تنبيهات العائلة',description:'إشعارات الرسائل وطلبات المتابعة',importance:Importance.high,enableVibration:true));_initialized=true;}
  Future<void> show({required String title,required String body,String? imageUrl,String? payload}) async {await init();String? localImage;if(imageUrl!=null&&imageUrl.trim().isNotEmpty)localImage=await _downloadImage(imageUrl.trim());final details=AndroidNotificationDetails(_channelId,'تنبيهات العائلة',channelDescription:'إشعارات الرسائل وطلبات المتابعة',importance:Importance.high,priority:Priority.high,playSound:true,largeIcon:localImage==null?null:FilePathAndroidBitmap(localImage),styleInformation:localImage==null?null:BigPictureStyleInformation(FilePathAndroidBitmap(localImage),hideExpandedLargeIcon:false,contentTitle:title,summaryText:body));await _plugin.show(DateTime.now().millisecondsSinceEpoch.remainder(100000000),title,body,NotificationDetails(android:details),payload:payload);}
  Future<String?> _downloadImage(String url) async {try{final uri=Uri.tryParse(url);if(uri==null||(uri.scheme!='http'&&uri.scheme!='https'))return null;final client=HttpClient();final request=await client.getUrl(uri);final response=await request.close();if(response.statusCode<200||response.statusCode>=300)return null;final dir=await getTemporaryDirectory();final file=File('${dir.path}/push_sender_${DateTime.now().microsecondsSinceEpoch}.jpg');await response.pipe(file.openWrite());client.close(force:true);return await file.exists()?file.path:null;}catch(_){return null;}}
}
