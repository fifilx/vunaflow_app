import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _loading = true;
  List<dynamic> _notifications = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.get('/api/notifications');
      setState(() => _notifications = res['data'] as List<dynamic>);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markAllRead() async {
    try {
      await ApiService.patch('/api/notifications/read-all');
      _load();
    } catch (_) {}
  }

  Future<void> _markRead(String id) async {
    try {
      await ApiService.patch('/api/notifications/$id/read');
      _load();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [TextButton(onPressed: _markAllRead, child: const Text('Mark all read'))],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _notifications.isEmpty
                  ? ListView(
                      children: const [
                        Padding(
                          padding: EdgeInsets.all(40),
                          child: Center(child: Text('No notifications yet.')),
                        ),
                      ],
                    )
                  : ListView.builder(
                      itemCount: _notifications.length,
                      itemBuilder: (context, i) {
                        final n = _notifications[i];
                        final unread = n['is_read'] == false;
                        return ListTile(
                          onTap: () => _markRead(n['id']),
                          leading: CircleAvatar(
                            backgroundColor: unread ? AppColors.primary.withValues(alpha: 0.12) : AppColors.border,
                            child: Icon(Icons.notifications, color: unread ? AppColors.primary : AppColors.textSecondary, size: 18),
                          ),
                          title: Text(n['title'], style: TextStyle(fontWeight: unread ? FontWeight.w700 : FontWeight.w500)),
                          subtitle: Text(n['message']),
                          trailing: Text(DateFormat.MMMd().format(DateTime.parse(n['created_at'])), style: Theme.of(context).textTheme.bodyMedium),
                        );
                      },
                    ),
            ),
    );
  }
}
