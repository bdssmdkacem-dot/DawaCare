import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'chat_page.dart';

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _contacts = [];
  final _db = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = _db.auth.currentUser?.id;
    if (id == null) return;

    try {
      final linkedRows = await _db
          .from('caregiver_patient')
          .select('patient_id, caregiver_id')
          .or('patient_id.eq.$id,caregiver_id.eq.$id');

      final contactById = <String, Map<String, dynamic>>{};

      for (final raw in linkedRows) {
        final row = Map<String, dynamic>.from(raw);
        final patientId = row['patient_id'] as String?;
        final caregiverId = row['caregiver_id'] as String?;
        if (patientId == null || caregiverId == null) continue;

        if (patientId == id) {
          // Patient can message every linked caregiver/viewer.
          contactById[caregiverId] = {
            'id': caregiverId,
            'patient_id': patientId,
          };
        } else if (caregiverId == id) {
          // Caregiver/viewer can message the patient.
          contactById[patientId] = {
            'id': patientId,
            'patient_id': patientId,
          };
        }
      }

      // A caregiver/viewer can also message the other caregivers/viewers
      // linked to the same patient(s). Keep this separate from the first
      // query so the patient-facing behavior remains unchanged.
      final patientIds = contactById.values
          .map((c) => c['patient_id'] as String)
          .toSet()
          .toList();

      if (patientIds.isNotEmpty) {
        final coCaregiverRows = await _db
            .from('caregiver_patient')
            .select('patient_id, caregiver_id')
            .inFilter('patient_id', patientIds);

        for (final raw in coCaregiverRows) {
          final row = Map<String, dynamic>.from(raw);
          final patientId = row['patient_id'] as String?;
          final caregiverId = row['caregiver_id'] as String?;
          if (patientId == null || caregiverId == null) continue;
          if (caregiverId == id) continue;

          contactById.putIfAbsent(caregiverId, () {
            return {
              'id': caregiverId,
              'patient_id': patientId,
            };
          });
        }
      }

      final contactIds = contactById.keys.toList();
      final profiles = contactIds.isEmpty
          ? <dynamic>[]
          : await _db
              .from('profiles')
              .select('id, full_name, avatar_url')
              .inFilter('id', contactIds);

      final profileById = <String, Map<String, dynamic>>{};
      for (final raw in profiles) {
        final profile = Map<String, dynamic>.from(raw);
        final profileId = profile['id'] as String?;
        if (profileId != null) profileById[profileId] = profile;
      }

      final list = <Map<String, dynamic>>[];
      for (final contact in contactById.values) {
        final contactId = contact['id'] as String;
        final profile = profileById[contactId];
        if (profile == null) continue;

        list.add({
          'id': contactId,
          'name': profile['full_name'] ?? 'مستخدم',
          'avatar': profile['avatar_url'],
          'patient_id': contact['patient_id'],
        });
      }

      list.sort((a, b) =>
          (a['name'] as String).compareTo(b['name'] as String));

      if (mounted) setState(() => _contacts = list);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر تحميل جهات الاتصال.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المحادثات')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _contacts.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 120),
                        Center(child: Text('لا توجد جهات مرتبطة للمحادثة.')),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _contacts.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final c = _contacts[i];
                        final avatar = c['avatar'] as String?;
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundImage: avatar?.isNotEmpty == true
                                  ? NetworkImage(avatar!)
                                  : null,
                              child: avatar?.isNotEmpty == true
                                  ? null
                                  : const Icon(Icons.person_rounded),
                            ),
                            title: Text(
                              c['name'] as String,
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                            subtitle: const Text('رسالة نصية أو صوتية أو صورة'),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ChatPage(
                                  patientId: c['patient_id'] as String,
                                  otherUserId: c['id'] as String,
                                  otherName: c['name'] as String,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
