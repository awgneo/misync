import 'package:flutter/material.dart';

class MiTab {
  final String label;
  final Widget child;

  const MiTab({
    required this.label,
    required this.child,
  });
}

class MiTabs extends StatelessWidget {
  final List<MiTab> tabs;

  const MiTabs({
    super.key,
    required this.tabs,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: tabs.length,
      child: Column(
        children: [
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: const Color(0xFF00E5FF),
            labelColor: const Color(0xFF00E5FF),
            unselectedLabelColor: Colors.grey,
            dividerColor: const Color(0xFF26324D),
            tabs: tabs.map((t) => Tab(text: t.label.toUpperCase())).toList(),
          ),
          Expanded(
            child: TabBarView(
              children: tabs.map((t) => t.child).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
