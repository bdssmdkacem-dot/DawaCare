import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/theme/app_colors.dart';
import 'chat_page.dart';

class ChatListPage extends StatefulWidget { const ChatListPage({super.key}); @override State<ChatListPage> createState()=>_ChatListPageState(); }
class _ChatListPageState extends State<ChatListPage>{
  bool _loading=true; List<Map<String,dynamic>> _contacts=[];
  final _db=Supabase.instance.client;
  @override void initState(){super.initState();_load();}
  Future<void> _load() async { final id=_db.auth.currentUser?.id; if(id==null)return; try{
    final incoming=await _db.from('caregiver_patient').select('patient_id,caregiver_id,patient:profiles!patient_id(id,full_name,avatar_url),caregiver:profiles!caregiver_id(id,full_name,avatar_url)').or('patient_id.eq.$id,caregiver_id.eq.$id');
    final list=<Map<String,dynamic>>[];
    for(final raw in incoming){final r=Map<String,dynamic>.from(raw);final patient=Map<String,dynamic>.from(r['patient'] as Map);final caregiver=Map<String,dynamic>.from(r['caregiver'] as Map);final meIsPatient=patient['id']==id;final other=meIsPatient?caregiver:patient;list.add({'id':other['id'],'name':other['full_name']??'مستخدم','avatar':other['avatar_url']});}
    if(mounted)setState(()=>_contacts=list);
  }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('تعذر تحميل جهات الاتصال.')));}finally{if(mounted)setState(()=>_loading=false);}}
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('المحادثات')),body:_loading?const Center(child:CircularProgressIndicator()):RefreshIndicator(onRefresh:_load,child:_contacts.isEmpty?ListView(children:const[ SizedBox(height:120),Center(child:Text('لا توجد جهات مرتبطة للمحادثة.')) ]):ListView.separated(padding:const EdgeInsets.all(16),itemCount:_contacts.length,separatorBuilder:(_,__)=>const SizedBox(height:8),itemBuilder:(context,i){final c=_contacts[i];final avatar=c['avatar'] as String?;return Card(child:ListTile(leading:CircleAvatar(backgroundImage:avatar?.isNotEmpty==true?NetworkImage(avatar!):null,child:avatar?.isNotEmpty==true?null:const Icon(Icons.person_rounded)),title:Text(c['name'] as String,style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:const Text('رسالة نصية أو صوتية أو صورة'),trailing:const Icon(Icons.chevron_right_rounded),onTap:()=>Navigator.of(context).push(MaterialPageRoute(builder:(_)=>ChatPage(patientId:_contactsPatientId(c['id'] as String),otherUserId:c['id'] as String,otherName:c['name'] as String)))));})));
  String _contactsPatientId(String other){final me=_db.auth.currentUser!.id;final row=_contacts.firstWhere((c)=>c['id']==other);return row['_patient_id'] as String? ?? me;}
}
