import 'dart:io';
import 'package:flutter/services.dart';

import 'gl_call_pip_platform_interface.dart';

typedef PipModeChanged = void Function(bool inPip);
typedef VoidCb = void Function();
typedef PipAction = void Function(String id, Map<String, dynamic>? extras);
typedef OpenFromNotification = void Function(String route);

class GlCallPip {
  static const MethodChannel _channel = MethodChannel('gl_call_pip');

  static PipModeChanged? _onPipChanged;
  static VoidCb? _onUserLeaveHint;
  static PipAction? _onAction;
  static OpenFromNotification? _onOpenFromNotification;

  static Future<bool> isAvailable() async {
    return await _channel.invokeMethod<bool>('isAvailable') ?? false;
  }

  static Future<bool> enter({
    int width = 9,
    int height = 16,
    bool autoEnterOnMinimize = false,
    List<Map<String, dynamic>>? actions,
  }) async {
    final ok = await _channel.invokeMethod<bool>('enter', {
      'width': width,
      'height': height,
      'autoEnterOnMinimize': autoEnterOnMinimize,
      if (actions != null) 'actions': actions,
    });
    return ok ?? false;
  }

  static Future<void> updateActions(List<Map<String, dynamic>> actions) async {
    await _channel.invokeMethod('updateActions', {'actions': actions});
  }

  static void initCallbacks({
    PipModeChanged? onPipChanged,
    VoidCb? onUserLeaveHint,
    PipAction? onAction,
    OpenFromNotification? onOpenFromNotification,
  }) {
    _onPipChanged = onPipChanged;
    _onUserLeaveHint = onUserLeaveHint;
    _onAction = onAction;
    _onOpenFromNotification = onOpenFromNotification;

    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onPipModeChanged':
          final inPip = (call.arguments as Map?)?['inPip'] == true;
          _onPipChanged?.call(inPip);
          break;
        case 'onUserLeaveHint':
          _onUserLeaveHint?.call();
          break;
        case 'onAction':
          final args = (call.arguments as Map?) ?? const {};
          final id = args['id']?.toString() ?? '';
          final extras = (args['extras'] as Map?)?.cast<String, dynamic>();
          if (id.isNotEmpty) _onAction?.call(id, extras);
          break;
        case 'onOpenFromNotification':
          final route =
              (call.arguments as Map?)?['route']?.toString() ?? '/call';
          _onOpenFromNotification?.call(route);
          break;
      }
      return null;
    });
  }

  static Future<void> setAutoEnterOnMinimize(bool enabled) async {
    await _channel.invokeMethod('setAutoEnterOnMinimize', {'enabled': enabled});
  }

  static Future<bool> isInPip() async {
    return await _channel.invokeMethod<bool>('isInPip') ?? false;
  }

  static Future<void> updateAspectRatio({
    required int width,
    required int height,
  }) async {
    await _channel.invokeMethod('updateAspectRatio', {
      'width': width,
      'height': height,
    });
  }

  static Future<void> bringToForeground() async {
    await _channel.invokeMethod('bringToForeground');
  }

  static Future<void> showOngoingCallNotification({
    String title = 'Call running',
    String text = 'Tap to return',
    String route = '/call',
  }) async {
    if (Platform.isAndroid) {
      await _channel.invokeMethod('showOngoingCallNotification', {
        'title': title,
        'text': text,
        'route': route,
      });
    }
  }

  static Future<void> cancelOngoingCallNotification() async {
    if (Platform.isAndroid) {
      await _channel.invokeMethod('cancelOngoingCallNotification');
    }
  }

  static Future<bool> hasOverlayPermission() async {
    if (!Platform.isAndroid) return false;
    return await _channel.invokeMethod<bool>('hasOverlayPermission') ?? false;
  }

  static Future<void> requestOverlayPermission() async {
    if (Platform.isAndroid) {
      await _channel.invokeMethod('requestOverlayPermission');
    }
  }

  static Future<void> showGlobalCallBanner({
    String title = 'Ongoing call',
    String text = 'Tap to return',
    String route = '/call',
  }) async {
    if (Platform.isAndroid) {
      await _channel.invokeMethod('showGlobalCallBanner', {
        'title': title,
        'text': text,
        'route': route,
      });
    }
  }

  static Future<void> hideGlobalCallBanner() async {
    if (Platform.isAndroid) {
      await _channel.invokeMethod('hideGlobalCallBanner');
    }
  }

  static Future<void> startOngoingCallChip({
    String title = 'Ongoing call',
    String text = 'Tap to return',
    String route = '/call',
    required int startMs, // millisecondsSinceEpoch of call start
  }) async {
    if (Platform.isAndroid) {
      await _channel.invokeMethod('startOngoingCallChip', {
        'title': title,
        'text': text,
        'route': route,
        'startMs': startMs,
      });
    }
  }

  static Future<void> stopOngoingCallChip() async {
    if (Platform.isAndroid) {
      await _channel.invokeMethod('stopOngoingCallChip');
    }
  }

  static Future<void> stop() async {
    await _channel.invokeMethod('stop');
  }

  Future<String?> getPlatformVersion() {
    return GlCallPipPlatform.instance.getPlatformVersion();
  }

  static Future<void> prepareIOSAgoraPiP({
    required String appId,
    required String channelId,
    required String token,
    required int remoteUid,
  }) async {
    if (Platform.isIOS) {
      await _channel.invokeMethod('prepareIOSAgoraPiP', {
        'appId': appId,
        'channelId': channelId,
        'token': token,
        'remoteUid': remoteUid,
      });
    }
  }
}
