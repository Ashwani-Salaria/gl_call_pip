import Flutter
import UIKit
import AVKit
import AVFoundation
 
public final class GlCallPipPlugin: NSObject, FlutterPlugin {
  private var channel: FlutterMethodChannel?

  // iOS 15+ sample-buffer PiP
  private var displayLayer: AVSampleBufferDisplayLayer?
  private var pipController: AVPictureInPictureController?
  private var isInPip: Bool = false

  // stored for debugging / future Agora wiring
  private var agoraAppId: String?
  private var agoraChannelId: String?
  private var agoraToken: String?
  private var agoraRemoteUid: Int?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "gl_call_pip",
      binaryMessenger: registrar.messenger()
    )
    let instance = GlCallPipPlugin()
    instance.channel = channel
    registrar.addMethodCallDelegate(instance, channel: channel)
  }
 
  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPlatformVersion":
      result("iOS " + UIDevice.current.systemVersion)
    case "isAvailable":
      if #available(iOS 9.0, *) {
        result(AVPictureInPictureController.isPictureInPictureSupported())
      } else {
        result(false)
      }
    case "isInPip":
      result(isInPip)
    case "prepareIOSAgoraPiP":
      guard let args = call.arguments as? [String: Any] else {
        result(false)
        return
      }
      agoraAppId = args["appId"] as? String
      agoraChannelId = args["channelId"] as? String
      agoraToken = args["token"] as? String
      agoraRemoteUid = args["remoteUid"] as? Int
      // NOTE: Real Agora → PiP frame piping should be implemented by attaching
      // an Agora video frame observer and enqueuing CMSampleBuffers into displayLayer.
      result(true)
    case "enter":
      enterPip(result: result)
    case "stop":
      stopPip(result: result)
    case "updateAspectRatio",
         "setAutoEnterOnMinimize",
         "updateActions",
         "bringToForeground",
         "showOngoingCallNotification",
         "cancelOngoingCallNotification",
         "startOngoingCallChip",
         "stopOngoingCallChip",
         "showGlobalCallBanner",
         "hideGlobalCallBanner",
         "hasOverlayPermission",
         "requestOverlayPermission":
      // iOS no-op implementations. These are Android-specific helpers in this plugin.
      // Returning a successful result prevents MissingPluginException crashes.
      result(true)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

// MARK: - PiP internals

extension GlCallPipPlugin: AVPictureInPictureControllerDelegate,
  AVPictureInPictureSampleBufferPlaybackDelegate {

  private func enterPip(result: @escaping FlutterResult) {
    guard #available(iOS 15.0, *) else {
      result(false)
      return
    }

    if pipController == nil {
      let layer = AVSampleBufferDisplayLayer()
      layer.videoGravity = .resizeAspect
      displayLayer = layer

      let source = AVPictureInPictureController.ContentSource(
        sampleBufferDisplayLayer: layer,
        playbackDelegate: self
      )

      let controller = AVPictureInPictureController(contentSource: source)
      controller.delegate = self
      pipController = controller
    }

    guard let controller = pipController else {
      result(false)
      return
    }

    if controller.isPictureInPictureActive {
      result(true)
      return
    }

    if !controller.isPictureInPicturePossible {
      // Still return false, but do not crash; Flutter should fallback to in-app PiP.
      debugPrint("[gl_call_pip][iOS] PiP not possible right now (missing frames / background state).")
      result(false)
      return
    }

    controller.startPictureInPicture()
    result(true)
  }

  private func stopPip(result: @escaping FlutterResult) {
    guard #available(iOS 15.0, *) else {
      result(false)
      return
    }
    if let controller = pipController, controller.isPictureInPictureActive {
      controller.stopPictureInPicture()
    }
    result(true)
  }

  private func notifyPipChanged(_ inPip: Bool) {
    isInPip = inPip
    channel?.invokeMethod("onPipModeChanged", arguments: ["inPip": inPip])
  }

  // MARK: AVPictureInPictureControllerDelegate

  public func pictureInPictureControllerWillStartPictureInPicture(
    _ pictureInPictureController: AVPictureInPictureController
  ) {
    notifyPipChanged(true)
  }

  public func pictureInPictureControllerWillStopPictureInPicture(
    _ pictureInPictureController: AVPictureInPictureController
  ) {
    notifyPipChanged(false)
  }

  public func pictureInPictureController(
    _ pictureInPictureController: AVPictureInPictureController,
    failedToStartPictureInPictureWithError error: Error
  ) {
    debugPrint("[gl_call_pip][iOS] failedToStartPiP error=\(error)")
    notifyPipChanged(false)
  }

  // MARK: AVPictureInPictureSampleBufferPlaybackDelegate

  public func pictureInPictureController(
    _ pictureInPictureController: AVPictureInPictureController,
    setPlaying playing: Bool
  ) {
    // No-op: actual playback control should be wired to Agora or call state.
  }

  public func pictureInPictureControllerTimeRangeForPlayback(
    _ pictureInPictureController: AVPictureInPictureController
  ) -> CMTimeRange {
    return CMTimeRange(start: .zero, duration: .positiveInfinity)
  }

  public func pictureInPictureControllerIsPlaybackPaused(
    _ pictureInPictureController: AVPictureInPictureController
  ) -> Bool {
    return false
  }

  public func pictureInPictureController(
    _ pictureInPictureController: AVPictureInPictureController,
    didTransitionToRenderSize newRenderSize: CMVideoDimensions
  ) {
    // Flutter UI should relayout on resume; this callback is kept for logging.
    debugPrint("[gl_call_pip][iOS] didTransitionToRenderSize \(newRenderSize.width)x\(newRenderSize.height)")
  }
}
 
 