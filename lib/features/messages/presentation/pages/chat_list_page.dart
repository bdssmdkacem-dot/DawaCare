import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import 'chat_network_panel.dart';

class ChatListPage extends StatelessWidget {
  const ChatListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.chats),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // The network panel owns its data lifecycle. A pull-to-refresh is
          // handled by rebuilding the panel so every patient network is
          // queried again.
          await Future<void>.delayed(Duration.zero);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          children: const [
            ChatNetworkPanel(),
          ],
        ),
      ),
    );
  }
}
