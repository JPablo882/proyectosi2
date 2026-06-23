import 'package:flutter/material.dart';

class NotificationItem {
  final String title;
  final String body;
  final String date;

  NotificationItem({
    required this.title,
    required this.body,
    required this.date,
  });
}

class NotificationProvider extends ChangeNotifier {
  static final NotificationProvider _instance = NotificationProvider._internal();
  factory NotificationProvider() => _instance;
  NotificationProvider._internal();

  final List<NotificationItem> _notifications = [];

  List<NotificationItem> get notifications => _notifications;

  int get unreadCount => _notifications.length; // Por ahora contamos todas como "no leídas" si queremos un badge.

  void addNotification(String title, String body, String date) {
    _notifications.insert(0, NotificationItem(
      title: title,
      body: body,
      date: date,
    ));
    notifyListeners();
  }

  void clearNotifications() {
    _notifications.clear();
    notifyListeners();
  }
}
