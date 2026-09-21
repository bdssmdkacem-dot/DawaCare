import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/notifications/routine_reminder_service.dart';

class RoutineReminderPage extends StatefulWidget {
  const RoutineReminderPage({super.key});

  @override
  State<RoutineReminderPage> createState() => _RoutineReminderPageState();
}

class _RoutineReminderPageState extends State<RoutineReminderPage> {
  final _titleController = TextEditingController();
  TimeOfDay _time = const TimeOfDay(hour: 9, minute: 0);
  List<RoutineReminder> _items = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final items = await RoutineReminderService.instance.load();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _add() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    final next = [
      ..._items,
      RoutineReminder(
        id: const Uuid().v4(),
        title: title,
        hour: _time.hour,
        minute: _time.minute,
      ),
    ];
    await RoutineReminderService.instance.save(next);
    if (!mounted) return;
    _titleController.clear();
    setState(() => _items = next);
  }

  Future<void> _remove(RoutineReminder item) async {
    final next = _items.where((e) => e.id != item.id).toList();
    await RoutineReminderService.instance.save(next);
    if (!mounted) return;
    setState(() => _items = next);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null && mounted) setState(() => _time = picked);
  }

  String _timeText(RoutineReminder item) {
    return '${item.hour.toString().padLeft(2, '0')}:${item.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My reminders'),
        actions: [
          IconButton(
            tooltip: 'Notification permissions',
            onPressed: RoutineReminderService.instance.requestPermissions,
            icon: const Icon(Icons.notifications_active_outlined),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                Card(
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        TextField(
                          controller: _titleController,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _add(),
                          decoration: const InputDecoration(
                            labelText: 'Reminder',
                            hintText: 'Example: Study, workout, call...',
                            prefixIcon: Icon(Icons.task_alt_rounded),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _pickTime,
                                icon: const Icon(Icons.schedule_rounded),
                                label: Text(
                                  'Time: ${_time.format(context)}',
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            FilledButton.icon(
                              onPressed: _add,
                              icon: const Icon(Icons.add_rounded),
                              label: const Text('Add'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_items.isEmpty)
                  const Card(
                    elevation: 0,
                    child: Padding(
                      padding: EdgeInsets.all(28),
                      child: Column(
                        children: [
                          Icon(Icons.event_note_rounded, size: 42),
                          SizedBox(height: 10),
                          Text(
                            'No reminders yet',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          SizedBox(height: 5),
                          Text(
                            'Create simple daily reminders for your routine.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ..._items.map(
                    (item) => Card(
                      elevation: 0,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              AppColors.primary.withValues(alpha: .10),
                          child: Icon(
                            Icons.notifications_none_rounded,
                            color: AppColors.primary,
                          ),
                        ),
                        title: Text(
                          item.title,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text('Daily at ${_timeText(item)}'),
                        trailing: IconButton(
                          tooltip: 'Delete',
                          onPressed: () => _remove(item),
                          icon: const Icon(Icons.delete_outline_rounded),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
