import Flutter
import UIKit
 
public class GlCallPipPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "gl_call_pip", binaryMessenger: registrar.messenger())
    let instance = GlCallPipPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }
 
  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPlatformVersion":
      result("iOS " + UIDevice.current.systemVersion)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
 
 