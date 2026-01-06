import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'gl_call_pip_method_channel.dart';

abstract class GlCallPipPlatform extends PlatformInterface {
  /// Constructs a GlCallPipPlatform.
  GlCallPipPlatform() : super(token: _token);

  static final Object _token = Object();

  static GlCallPipPlatform _instance = MethodChannelGlCallPip();

  /// The default instance of [GlCallPipPlatform] to use.
  ///
  /// Defaults to [MethodChannelGlCallPip].
  static GlCallPipPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [GlCallPipPlatform] when
  /// they register themselves.
  static set instance(GlCallPipPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
