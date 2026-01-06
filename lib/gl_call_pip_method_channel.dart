import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'gl_call_pip_platform_interface.dart';

/// An implementation of [GlCallPipPlatform] that uses method channels.
class MethodChannelGlCallPip extends GlCallPipPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('gl_call_pip');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }
}
