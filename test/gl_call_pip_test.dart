import 'package:flutter_test/flutter_test.dart';
import 'package:gl_call_pip/gl_call_pip.dart';
import 'package:gl_call_pip/gl_call_pip_platform_interface.dart';
import 'package:gl_call_pip/gl_call_pip_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockGlCallPipPlatform
    with MockPlatformInterfaceMixin
    implements GlCallPipPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final GlCallPipPlatform initialPlatform = GlCallPipPlatform.instance;

  test('$MethodChannelGlCallPip is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelGlCallPip>());
  });

  test('getPlatformVersion', () async {
    GlCallPip GlCallPipPlugin = GlCallPip();
    MockGlCallPipPlatform fakePlatform = MockGlCallPipPlatform();
    GlCallPipPlatform.instance = fakePlatform;

    expect(await GlCallPipPlugin.getPlatformVersion(), '42');
  });
}
