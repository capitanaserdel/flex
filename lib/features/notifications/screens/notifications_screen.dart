import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../providers/service_providers.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  List<dynamic> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    try {
      final response = await ref.read(apiServiceProvider).get('/notifications');
      if (response.data['success'] == true) {
        setState(() {
          _notifications = response.data['data']['data'];
        });
      }
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  Future<void> _markAllAsRead() async {
    try {
      final response = await ref.read(apiServiceProvider).post('/notifications/mark-read');
      if (response.data['success'] == true) {
        setState(() {
          for (var n in _notifications) {
            n['is_read'] = true;
          }
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('All notifications marked as read!'),
              backgroundColor: AppColors.successGreen,
            ),
          );
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.softWhite,
      appBar: AppBar(
        title: Text('Notifications', style: AppTextStyles.displaySmall),
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          if (_notifications.isNotEmpty)
            TextButton(
              onPressed: _markAllAsRead,
              child: const Text('Mark all read', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('🔔', style: TextStyle(fontSize: 48)),
                      SizedBox(height: 16),
                      Text('No notifications yet!'),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _notifications.length,
                  itemBuilder: (context, index) {
                    final item = _notifications[index];
                    final isRead = item['is_read'] == true;
                    
                    return Container(
                      color: isRead ? Colors.transparent : AppColors.primary.withOpacity(0.04),
                      child: ListTile(
                        leading: _buildNotificationIcon(item['type']),
                        title: Text(
                          item['title'],
                          style: TextStyle(
                            fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(item['body']),
                        trailing: isRead
                            ? null
                            : const CircleAvatar(radius: 4, backgroundColor: AppColors.accentGold),
                        onTap: () {
                          // Mark single as read
                          ref.read(apiServiceProvider).post('/notifications/mark-read', data: {'id': item['id']});
                          setState(() {
                            item['is_read'] = true;
                          });
                          
                          // Handle deep link routing
                          if (item['deep_link'] != null) {
                            context.push(item['deep_link']);
                          }
                        },
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildNotificationIcon(String type) {
    String emoji = '🔔';
    Color bgColor = Colors.blue.shade50;
    
    switch (type) {
      case 'vote':
        emoji = '💛';
        bgColor = Colors.red.shade50;
        break;
      case 'rank':
        emoji = '🏆';
        bgColor = Colors.amber.shade50;
        break;
      case 'challenge':
        emoji = '🔥';
        bgColor = Colors.orange.shade50;
        break;
      case 'approval':
        emoji = '✅';
        bgColor = Colors.green.shade50;
        break;
      case 'rejection':
        emoji = '⚠️';
        bgColor = Colors.orange.shade50;
        break;
      default:
        emoji = '📢';
        bgColor = Colors.green.shade50;
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(emoji, style: const TextStyle(fontSize: 18)),
      ),
    );
  }
}
