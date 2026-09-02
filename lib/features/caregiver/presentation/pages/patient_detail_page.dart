import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../models/caregiver_link.dart';
import '../../../../models/dose_instance.dart';
import '../../../doses/presentation/providers/dose_provider.dart';
import '../../../patient/presentation/widgets/dose_card.dart';
import '../../data/caregiver_repository.dart';
import '../../domain/adherence_calculator.dart';
import '../widgets/adherence_chart.dart';
import 'voice_recorder_page.dart';

class PatientDetailPage extends StatefulWidget{final CaregiverLink link;const PatientDetailPage({super.key,required this.link});@override State<PatientDetailPage> createState()=>_PatientDetailPageState();}
class _PatientDetailPageState extends State<PatientDetailPage>{
 @override void initState(){super.initState();WidgetsBinding.instance.addPostFrameCallback((_){context.read<DoseProvider>().load(widget.link.patientId,scheduleReminders:false);});}
 void _openVoiceRecorder({DoseInstance? dose}){Navigator.of(context).push(MaterialPageRoute(builder:(_)=>VoiceRecorderPage(patientId:widget.link.patientId,patientName:widget.link.patientName,doseId:dose?.id,medicationName:dose?.medicationName,doseAmount:dose?.doseAmount,scheduledAt:dose?.scheduledAt)));}
 @override Widget build(BuildContext context){final l=AppLocalizations.of(context);final p=context.watch<DoseProvider>();return Scaffold(appBar:AppBar(title:Text(widget.link.patientName)),body:p.isLoading&&p.all.isEmpty?const LoadingIndicator():RefreshIndicator(onRefresh:()=>context.read<DoseProvider>().load(widget.link.patientId,scheduleReminders:false),child:ListView(padding:const EdgeInsets.all(16),children:[Card(child:Padding(padding:const EdgeInsets.all(16),child:AdherenceChart(stats:AdherenceCalculator.compute(p.all)))),const SizedBox(height:16),SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:()=>_openVoiceRecorder(),icon:const Icon(Icons.mic_rounded),label:Text(l.sendGeneralVoice))),const SizedBox(height:20),Text(l.today,style:Theme.of(context).textTheme.titleMedium),const SizedBox(height:10),if(p.todayDoses.isEmpty)Padding(padding:const EdgeInsets.symmetric(vertical:24),child:Center(child:Text(l.noScheduledMedicines)))else...p.todayDoses.map((dose)=>Padding(padding:const EdgeInsets.only(bottom:10),child:DoseCard(dose:dose,onTap:()=>_openVoiceRecorder(dose:dose),onConfirm:()=>context.read<DoseProvider>().confirm(dose,source:'CAREGIVER'),onSnooze:()=>context.read<DoseProvider>().snooze(dose,source:'CAREGIVER'),onSkip:()=>context.read<DoseProvider>().skip(dose,source:'CAREGIVER')))),const SizedBox(height:12),TextButton.icon(onPressed:()=>_confirmUnlink(context),icon:const Icon(Icons.link_off_rounded,color:Colors.redAccent),label:Text(l.removeLink,style:const TextStyle(color:Colors.redAccent))) ])));}
 Future<void> _confirmUnlink(BuildContext context)async{final l=AppLocalizations.of(context);final confirmed=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:Text(l.removeLinkTitle),content:Text(l.removeLinkBody(widget.link.patientName)),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:Text(l.cancel)),TextButton(onPressed:()=>Navigator.pop(ctx,true),child:Text(l.removeLink))]));if(confirmed==true&&context.mounted){await CaregiverRepository().unlink(widget.link.id);if(context.mounted)Navigator.of(context).pop();}}
}
