import 'dart:async';
import 'dart:ui';
import 'package:executive_app/firebase_options.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'screens/home_screen.dart';
import 'screens/incoming_call_screen.dart';
import 'models/call_model.dart';

final FlutterLocalNotificationsPlugin localNotifications =
    FlutterLocalNotificationsPlugin();

// Global navigator key so we can navigate from outside widget tree
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Called when FCM arrives while app is in background/killed.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    await _setupLocalNotifications();
    _showCallNotification(message);
  } catch (e, stack) {
    debugPrint('[BGHandler] error: $e');
    debugPrint(stack.toString());
  }
}

Future<void> _setupLocalNotifications() async {
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  await localNotifications.initialize(
    const InitializationSettings(android: androidInit),
    onDidReceiveNotificationResponse: _onNotificationTap,
  );

  // Create high-priority channel for incoming calls
  const channel = AndroidNotificationChannel(
    'incoming_calls',
    'Incoming Calls',
    description: 'Notifications for incoming calls',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );
  await localNotifications
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
}

void _showCallNotification(RemoteMessage message) {
  final data = message.data;
  if (data['type'] != 'incoming_call') return;

  final callerName = data['callerName'] ?? 'Unknown';
  final callId = data['callId'] ?? '';
  final roomId = data['roomId'] ?? '';

  localNotifications.show(
    callId.hashCode,
    'Incoming Call',
    '$callerName is calling...',
    NotificationDetails(
      android: AndroidNotificationDetails(
        'incoming_calls',
        'Incoming Calls',
        channelDescription: 'Notifications for incoming calls',
        importance: Importance.max,
        priority: Priority.max,
        fullScreenIntent: true,
        ongoing: true,
        autoCancel: false,
        playSound: true,
        enableVibration: true,
        icon: '@mipmap/ic_launcher',
      ),
    ),
    payload: '$callId|$roomId|$callerName',
  );
}

void _onNotificationTap(NotificationResponse response) {
  final payload = response.payload;
  if (payload == null) return;
  final parts = payload.split('|');
  if (parts.length < 3) return;

  final call = CallModel(
    callId: parts[0],
    roomId: parts[1],
    callerName: parts[2],
    callerId: '',
    status: 'ringing',
    timestamp: DateTime.now(),
  );

  // Cancel the ongoing notification
  localNotifications.cancel(parts[0].hashCode);

  navigatorKey.currentState?.pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => IncomingCallScreen(call: call)),
    (route) => false,
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    debugPrint('[FlutterError] ${details.exceptionAsString()}');
    debugPrint(details.stack.toString());
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('[PlatformError] $error');
    debugPrint(stack.toString());
    return true;
  };

  await runZonedGuarded(() async {
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    } catch (e, stack) {
      debugPrint('[main] Firebase init failed: $e');
      debugPrint(stack.toString());
    }

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    try {
      await _setupLocalNotifications();
    } catch (e, stack) {
      debugPrint('[main] Local notifications setup failed: $e');
      debugPrint(stack.toString());
    }

    localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    runApp(const ExecutiveApp());
  }, (error, stack) {
    debugPrint('[ZoneError] $error');
    debugPrint(stack.toString());
  });
}

class ExecutiveApp extends StatefulWidget {
  const ExecutiveApp({super.key});

  @override
  State<ExecutiveApp> createState() => _ExecutiveAppState();
}

class _ExecutiveAppState extends State<ExecutiveApp> {
  @override
  void initState() {
    super.initState();
    _setupFcmHandlers();
  }

  void _setupFcmHandlers() {
    // App opened from terminated state via notification tap
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) _handleCallMessage(message);
    });

    // App brought to foreground from background via notification tap
    FirebaseMessaging.onMessageOpenedApp.listen(_handleCallMessage);

    // FCM arrives while app is in foreground — show local notification
    FirebaseMessaging.onMessage.listen((message) {
      _showCallNotification(message);
    });
  }

  void _handleCallMessage(RemoteMessage message) {
    final data = message.data;
    if (data['type'] != 'incoming_call') return;

    final call = CallModel(
      callId: data['callId'] ?? '',
      roomId: data['roomId'] ?? '',
      callerName: data['callerName'] ?? 'Unknown',
      callerId: '',
      status: 'ringing',
      timestamp: DateTime.now(),
    );

    // Cancel the ongoing notification if showing
    localNotifications.cancel(call.callId.hashCode);

    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => IncomingCallScreen(call: call)),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Executive App',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32)),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
