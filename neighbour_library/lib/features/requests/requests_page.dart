import 'package:flutter/material.dart';
import 'package:neighbour_library/features/requests/tabs/active_tab.dart';
import 'package:neighbour_library/features/requests/tabs/history_tab.dart';
import 'package:neighbour_library/features/requests/tabs/incoming_tab.dart';
import 'package:neighbour_library/ui/app_scaffold.dart';

class RequestsPage extends StatelessWidget {
  const RequestsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: AppScaffold(
        title: 'Requests',
        body: Column(
          children: const [
            TabBar(
              tabs: [
                Tab(text: 'Incoming'),
                Tab(text: 'Active'),
                Tab(text: 'History'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [IncomingTab(), ActiveTab(), HistoryTab()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
