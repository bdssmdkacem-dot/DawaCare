import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import 'chat_page.dart';

class ChatNetworkPanel extends StatefulWidget {
  const ChatNetworkPanel({
    super.key,
    this.patientId,
    this.compact = false,
  });

  final String? patientId;
  final bool compact;

  @override
  State<ChatNetworkPanel> createState() => _ChatNetworkPanelState();
}

class _ChatNetworkPanelState extends State<ChatNetworkPanel> {
  final _db = Supabase.instance.client;
  bool _loading = true;
  List<_PatientNetwork> _networks = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final me = _db.auth.currentUser?.id;
    if (me == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final rows = await _db
          .from('caregiver_patient')
          .select('patient_id, caregiver_id, role')
          .or('patient_id.eq.$me,caregiver_id.eq.$me');

      final all = rows
          .map((r) => Map<String, dynamic>.from(r))
          .toList();

      final patientIds = <String>{};
      for (final row in all) {
        final patientId = row['patient_id'] as String?;
        if (patientId != null) patientIds.add(patientId);
      }

      if (widget.patientId != null) {
        patientIds
          ..clear()
          ..add(widget.patientId!);
      }

      // If the current user is a caregiver, discover every other caregiver
      // linked to each patient. If the current user is the patient, this
      // naturally returns every caregiver/family link for that patient.
      final networkRows = patientIds.isEmpty
          ? <dynamic>[]
          : await _db
              .from('caregiver_patient')
              .select('patient_id, caregiver_id, role')
              .inFilter('patient_id', patientIds.toList());

      final ids = <String>{...patientIds};
      for (final raw in networkRows) {
        final row = Map<String, dynamic>.from(raw);
        final caregiverId = row['caregiver_id'] as String?;
        if (caregiverId != null) {
          ids.add(caregiverId);
        }
      }

      if (widget.patientId == null && ids.length == patientIds.length) {
        // No linked people.
        if (mounted) {
          setState(() {
            _networks = [];
            _loading = false;
          });
        }
        return;
      }

      final profileRows = ids.isEmpty
          ? <dynamic>[]
          : await _db
              .from('profiles')
              .select('id, full_name, avatar_url')
              .inFilter('id', ids.toList());

      final profiles = <String, Map<String, dynamic>>{};
      for (final raw in profileRows) {
        final p = Map<String, dynamic>.from(raw);
        final id = p['id'] as String?;
        if (id != null) profiles[id] = p;
      }

      final networks = <_PatientNetwork>[];
      for (final patientId in patientIds) {
        final patient = profiles[patientId];
        if (patient == null) {
          continue;
        }

        final contacts = <_ChatContact>[];
        for (final raw in networkRows) {
          final row = Map<String, dynamic>.from(raw);
          if (row['patient_id'] != patientId) continue;
          final contactId = row['caregiver_id'] as String?;
          if (contactId == null || contactId == me) continue;
          final profile = profiles[contactId];
          if (profile == null) {
            continue;
          }
          contacts.add(_ChatContact(
            id: contactId,
            name: (profile['full_name'] as String?)?.trim() ?? '',
            avatar: profile['avatar_url'] as String?,
            role: row['role'] as String? ?? 'CAREGIVER',
          ));
        }

        // A caregiver must also be able to chat with the patient at the
        // center. A patient does not add themselves as a contact.
        if (me != patientId && contacts.every((c) => c.id != patientId)) {
          contacts.insert(
            0,
            _ChatContact(
              id: patientId,
              name: (patient['full_name'] as String?)?.trim() ?? '',
              avatar: patient['avatar_url'] as String?,
              role: 'PATIENT',
            ),
          );
        }

        final unique = <String, _ChatContact>{};
        for (final contact in contacts) {
          unique[contact.id] = contact;
        }

        networks.add(_PatientNetwork(
          patientId: patientId,
          patientName: (patient['full_name'] as String?)?.trim() ?? '',
          patientAvatar: patient['avatar_url'] as String?,
          contacts: unique.values.toList(),
        ));
      }

      if (mounted) {
        setState(() {
          _networks = networks;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('chat network load: $e');
      if (mounted) {
        setState(() {
          _networks = [];
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_networks.isEmpty) {
      return _empty(l);
    }

    if (widget.compact) {
      final network = _networks.first;
      return _compactNetwork(network, l);
    }

    return Column(
      children: [
        for (final network in _networks) ...[
          if (_networks.length > 1) _networkTitle(network, l),
          _networkCircle(network, l),
          if (_networks.length > 1) const SizedBox(height: 18),
        ],
      ],
    );
  }

  Widget _compactNetwork(_PatientNetwork network, AppLocalizations l) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.tr('مرافقوك وعائلتك', 'Caregivers and family', 'Accompagnants et famille'),
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
            ),
            const SizedBox(height: 4),
            Text(
              l.tr('اضغط على الشخص لفتح المحادثة مباشرة.', 'Tap a person to open the conversation.', 'Touchez une personne pour ouvrir directement la conversation.'),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 10),
            if (network.contacts.isEmpty)
              Text(l.tr(
                'لا يوجد أشخاص مرتبطون بك بعد.',
                'No linked people yet.',
                'Aucune personne liée pour le moment.',
              ))
            else
              SizedBox(
                height: 92,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: network.contacts.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 14),
                  itemBuilder: (_, index) {
                    final contact = network.contacts[index];
                    return _contactTile(network.patientId, contact, l);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _networkTitle(_PatientNetwork network, AppLocalizations l) {
    final name = network.patientName.isEmpty
        ? l.tr('المريض', 'Patient', 'Patient')
        : network.patientName;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Text(
          name,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }

  Widget _networkCircle(_PatientNetwork network, AppLocalizations l) {
    final contacts = network.contacts;
    const size = 330.0;
    const center = 165.0;
    const radius = 112.0;

    return SizedBox(
      height: size,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cx = constraints.maxWidth / 2;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: cx - 54,
                top: center - 54,
                child: _patientCenter(network, l),
              ),
              for (var i = 0; i < contacts.length; i++)
                ..._positionedContact(
                  network,
                  contacts[i],
                  i,
                  contacts.length,
                  cx,
                  center,
                  radius,
                  l,
                ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _positionedContact(
    _PatientNetwork network,
    _ChatContact contact,
    int index,
    int count,
    double cx,
    double cy,
    double radius,
    AppLocalizations l,
  ) {
    final angle = -math.pi / 2 + (2 * math.pi * index / math.max(count, 1));
    final x = cx + math.cos(angle) * radius - 34;
    final y = cy + math.sin(angle) * radius - 34;
    return [
      Positioned(
        left: x.clamp(4.0, double.infinity),
        top: y.clamp(4.0, 262.0),
        child: GestureDetector(
          onTap: () => _openChat(network.patientId, contact),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _avatar(contact.avatar, contact.name, 34, _contactColor(contact)),
              const SizedBox(height: 3),
              SizedBox(
                width: 76,
                child: Text(
                  contact.name.isEmpty
                      ? l.tr('مستخدم', 'User', 'Utilisateur')
                      : contact.name,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  Widget _patientCenter(_PatientNetwork network, AppLocalizations l) {
    final name = network.patientName.isEmpty
        ? l.tr('المريض', 'Patient', 'Patient')
        : network.patientName;
    return Column(
      children: [
        _avatar(network.patientAvatar, name, 54, AppColors.primary),
        const SizedBox(height: 4),
        SizedBox(
          width: 108,
          child: Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }

  Widget _contactTile(String patientId, _ChatContact contact, AppLocalizations l) {
    return GestureDetector(
      onTap: () => _openChat(patientId, contact),
      child: SizedBox(
        width: 72,
        child: Column(
          children: [
            _avatar(contact.avatar, contact.name, 30, _contactColor(contact)),
            const SizedBox(height: 4),
            Text(
              contact.name.isEmpty ? l.tr('مستخدم', 'User', 'Utilisateur') : contact.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatar(String? url, String name, double radius, Color color) {
    final initials = _initials(name);
    final hasImage = url != null && url.isNotEmpty;
    return CircleAvatar(
      radius: radius,
      backgroundColor: color.withValues(alpha: .16),
      backgroundImage: hasImage ? NetworkImage(url) : null,
      child: hasImage
          ? null
          : Text(
              initials,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: radius * .55,
              ),
            ),
    );
  }

  Color _contactColor(_ChatContact contact) {
    if (contact.role == 'PATIENT') return AppColors.primary;
    if (contact.role == 'VIEWER') return Colors.deepPurple;
    return AppColors.accentDark;
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts.first.runes.take(2).map(String.fromCharCode).join().toUpperCase();
    return '${String.fromCharCode(parts.first.runes.first)}${String.fromCharCode(parts.last.runes.first)}'.toUpperCase();
  }

  void _openChat(String patientId, _ChatContact contact) {
    if (contact.id == _db.auth.currentUser?.id) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatPage(
          patientId: patientId,
          otherUserId: contact.id,
          otherName: contact.name.isEmpty
              ? AppLocalizations.of(context).tr('مستخدم', 'User', 'Utilisateur')
              : contact.name,
        ),
      ),
    );
  }

  Widget _empty(AppLocalizations l) => Padding(
    padding: const EdgeInsets.all(20),
    child: Text(
      l.tr(
        'لا توجد جهات مرتبطة للمحادثة.',
        'No linked contacts for chat.',
        'Aucun contact lié pour discuter.',
      ),
      textAlign: TextAlign.center,
    ),
  );
}

class _PatientNetwork {
  final String patientId;
  final String patientName;
  final String? patientAvatar;
  final List<_ChatContact> contacts;

  const _PatientNetwork({
    required this.patientId,
    required this.patientName,
    required this.patientAvatar,
    required this.contacts,
  });
}

class _ChatContact {
  final String id;
  final String name;
  final String? avatar;
  final String role;

  const _ChatContact({
    required this.id,
    required this.name,
    required this.avatar,
    required this.role,
  });
}
