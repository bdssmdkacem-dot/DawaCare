import 'package:flutter/material.dart';

import '../../../../models/family_link_request.dart';
import '../providers/caregiver_provider.dart';

class FamilyLinkRequestsSection extends StatelessWidget {
  const FamilyLinkRequestsSection({
    super.key,
    required this.provider,
    required this.onRespond,
    required this.onCancel,
  });

  final CaregiverProvider provider;
  final Future<void> Function(FamilyLinkRequest request, bool approve) onRespond;
  final Future<void> Function(FamilyLinkRequest request) onCancel;

  @override
  Widget build(BuildContext context) {
    final incoming = provider.incomingRequests;
    final sent = provider.sentRequests;
    if (incoming.isEmpty && sent.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (incoming.isNotEmpty) ...[
          _header(context, 'دعوات واردة', Icons.mail_outline_rounded),
          ...incoming.map(
            (request) => _IncomingCard(
              request: request,
              onRespond: onRespond,
              busy: false,
            ),
          ),
        ],
        if (sent.isNotEmpty) ...[
          _header(context, 'طلبات أرسلتها', Icons.outbox_rounded),
          ...sent.map(
            (request) => _SentCard(
              request: request,
              onCancel: onCancel,
            ),
          ),
        ],
      ],
    );
  }

  Widget _header(BuildContext context, String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 21),
          const SizedBox(width: 8),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    );
  }
}

class _IncomingCard extends StatelessWidget {
  const _IncomingCard({
    required this.request,
    required this.onRespond,
    required this.busy,
  });

  final FamilyLinkRequest request;
  final Future<void> Function(FamilyLinkRequest request, bool approve) onRespond;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                child: Icon(Icons.person_add_alt_1_rounded),
              ),
              title: Text(request.caregiverName),
              subtitle: Text(
                request.relationshipLabel?.isNotEmpty == true
                    ? 'صلة القرابة: ${request.relationshipLabel}'
                    : 'يريد إضافتك إلى العائلة.',
              ),
            ),
            if (busy)
              const Center(child: CircularProgressIndicator())
            else
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => onRespond(request, true),
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('قبول'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => onRespond(request, false),
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('رفض'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _SentCard extends StatelessWidget {
  const _SentCard({required this.request, required this.onCancel});

  final FamilyLinkRequest request;
  final Future<void> Function(FamilyLinkRequest request) onCancel;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.schedule_rounded)),
        title: Text(request.patientName),
        subtitle: Text(
          request.relationshipLabel?.isNotEmpty == true
              ? 'صلة القرابة: ${request.relationshipLabel}'
              : 'بانتظار موافقة فرد العائلة',
        ),
        trailing: TextButton(
          onPressed: () => onCancel(request),
          child: const Text('إلغاء'),
        ),
      ),
    );
  }
}
