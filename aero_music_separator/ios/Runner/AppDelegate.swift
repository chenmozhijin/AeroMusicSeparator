import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, UIDocumentPickerDelegate {
  private var exportChannel: FlutterMethodChannel?
  private var pendingExportResult: FlutterResult?
  private var pendingTempExportURL: URL?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(
      forPlugin: "AeroExportChannel"
    )
    else {
      return
    }
    let channel = FlutterMethodChannel(
      name: "aero_music_separator/export",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handleExportMethodCall(call: call, result: result)
    }
    exportChannel = channel
  }

  private func handleExportMethodCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "exportFile" else {
      result(FlutterMethodNotImplemented)
      return
    }
    if pendingExportResult != nil {
      result(
        FlutterError(
          code: "pick_destination",
          message: "pick_destination: export is already active",
          details: nil
        )
      )
      return
    }
    guard
      let args = call.arguments as? [String: Any],
      let sourcePath = args["sourcePath"] as? String,
      let suggestedName = args["suggestedName"] as? String
    else {
      result(
        FlutterError(
          code: "pick_destination",
          message: "pick_destination: invalid export arguments",
          details: nil
        )
      )
      return
    }

    let trimmedPath = sourcePath.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedName = suggestedName.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmedPath.isEmpty || trimmedName.isEmpty {
      result(
        FlutterError(
          code: "pick_destination",
          message: "pick_destination: invalid export arguments",
          details: nil
        )
      )
      return
    }

    let sourceURL = URL(fileURLWithPath: trimmedPath)
    if !FileManager.default.isReadableFile(atPath: sourceURL.path) {
      result(
        FlutterError(
          code: "ffi_read",
          message: "ffi_read: source file is not readable: \(trimmedPath)",
          details: nil
        )
      )
      return
    }

    let tempExportURL = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("\(UUID().uuidString)_\(trimmedName)")
    do {
      if FileManager.default.fileExists(atPath: tempExportURL.path) {
        try FileManager.default.removeItem(at: tempExportURL)
      }
      try FileManager.default.copyItem(at: sourceURL, to: tempExportURL)
    } catch {
      result(
        FlutterError(
          code: "stream_copy",
          message: "stream_copy: failed to prepare export file: \(error)",
          details: nil
        )
      )
      return
    }

    guard let presenter = topViewController() else {
      cleanupTempExportFile(at: tempExportURL)
      result(
        FlutterError(
          code: "pick_destination",
          message: "pick_destination: unable to find active view controller",
          details: nil
        )
      )
      return
    }

    let picker: UIDocumentPickerViewController
    if #available(iOS 14.0, *) {
      picker = UIDocumentPickerViewController(forExporting: [tempExportURL], asCopy: true)
    } else {
      picker = UIDocumentPickerViewController(url: tempExportURL, in: .exportToService)
    }
    picker.delegate = self

    pendingExportResult = result
    pendingTempExportURL = tempExportURL
    DispatchQueue.main.async {
      presenter.present(picker, animated: true, completion: nil)
    }
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    let result = pendingExportResult
    pendingExportResult = nil
    cleanupTempExportFile(at: pendingTempExportURL)
    pendingTempExportURL = nil
    result?(urls.first?.path)
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    let result = pendingExportResult
    pendingExportResult = nil
    cleanupTempExportFile(at: pendingTempExportURL)
    pendingTempExportURL = nil
    result?(nil)
  }

  private func topViewController() -> UIViewController? {
    var root: UIViewController?
    if #available(iOS 13.0, *) {
      root = UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .flatMap { $0.windows }
        .first(where: \.isKeyWindow)?
        .rootViewController
    }
    if root == nil {
      root = window?.rootViewController
    }
    guard var current = root else {
      return nil
    }
    while let presented = current.presentedViewController {
      current = presented
    }
    return current
  }

  private func cleanupTempExportFile(at url: URL?) {
    guard let target = url else {
      return
    }
    if FileManager.default.fileExists(atPath: target.path) {
      try? FileManager.default.removeItem(at: target)
    }
  }
}
