import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_local_notifications_platform_interface/flutter_local_notifications_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final MockFlutterLocalNotificationsPlugin mock =
      MockFlutterLocalNotificationsPlugin();
  FlutterLocalNotificationsPlatform.instance = mock;

  test('Creates DarwinNotificationAttachment when file path is specified', () {
    expect(const DarwinNotificationAttachment(''),
        isA<DarwinNotificationAttachment>());
  });
}

class MockMethodChannel extends Fake implements MethodChannel {}

class MockFlutterLocalNotificationsPlugin extends Fake
    with
        MockPlatformInterfaceMixin // ignore: prefer_mixin
    implements
        FlutterLocalNotificationsPlatform {}
