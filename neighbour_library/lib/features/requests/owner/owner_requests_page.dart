import 'package:flutter/material.dart';
import '../../../ui/app_scaffold.dart';
import 'owner_incoming_tab.dart';
import 'owner_active_tab.dart';
import 'owner_history_tab.dart';

class OwnerRequestsPage extends StatelessWidget {
  const OwnerRequestsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: AppScaffold(
        title: 'Requests',
        bottom: const TabBar(
          tabs: [
            Tab(text: 'Incoming'),
            Tab(text: 'Active'),
            Tab(text: 'History'),
          ],
        ),
        body: const TabBarView(
          children: [OwnerIncomingTab(), OwnerActiveTab(), OwnerHistoryTab()],
        ),
      ),
    );
  }
}
