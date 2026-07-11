import 'package:flutter/material.dart';
import '../screen.dart';
import '../widgets/panel.dart';
import '../widgets/items.dart';
import '../widgets/item.dart';
import 'module.dart';
import 'blobs/calendars.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ScreenState<CalendarScreen> {
  @override
  CalendarModule get module => CalendarModule.instance;

  List<PhoneCalendar> _allCalendars = [];

  @override
  Future<void> refresh() async {
    await super.refresh();
    await _refreshCalendars();
  }

  Future<void> _refreshCalendars() async {
    final list = await module.getCalendars();
    setState(() {
      _allCalendars = list;
    });
  }

  @override
  Widget buildScreen(BuildContext context, bool connected) {
    if (_allCalendars.isEmpty) {
      return const MiPanel(
        child: Center(
          child: Text(
            'No calendars found on device',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ),
      );
    }

    return ListenableBuilder(
      listenable: CalendarsBlob.instance,
      builder: (context, _) {
        // Sort calendars: Enabled first (alphabetically), then Disabled (alphabetically)
        final enabledCalendars =
            _allCalendars
                .where((c) => CalendarsBlob.instance.getEnabled(c.id))
                .toList()
              ..sort(
                (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
              );

        final disabledCalendars =
            _allCalendars
                .where((c) => !CalendarsBlob.instance.getEnabled(c.id))
                .toList()
              ..sort(
                (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
              );

        final sortedCalendars = [...enabledCalendars, ...disabledCalendars];

        return MiPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MiItems(
                children: sortedCalendars.map((calendar) {
                  final isEnabled = CalendarsBlob.instance.getEnabled(
                    calendar.id,
                  );
                  return MiItem(
                    title: calendar.name,
                    subtitle: calendar.account,
                    primaryIcon: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Color(calendar.color).withAlpha(255),
                        shape: BoxShape.circle,
                      ),
                    ),
                    enabled: isEnabled,
                    toggled: (value) async {
                      await module.setCalendarEnabled(calendar.id, value);
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }
}
