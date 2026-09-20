import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import 'chat_network_panel.dart';

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  final GlobalKey<_ChatNetworkPanelState> _networkKey =
      GlobalKey<_ChatNetworkPanelState>();

  Future<void> _refresh() async {
    await _networkKey.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.chats),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          children: [
            ChatNetworkPanel(key: _networkKey),
          ],
        ),
      ),
    );
  }
}
