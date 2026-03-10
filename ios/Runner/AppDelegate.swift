import BackgroundTasks
import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  // Retained after didInitializeImplicitFlutterEngine to route background-task
  // callbacks into Flutter.
  private var bgMethodChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // BGTaskScheduler registration MUST happen before
    // application(_:didFinishLaunchingWithOptions:) returns.
    registerBackgroundTasks()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    setupBackgroundTaskChannel(engineBridge: engineBridge)
  }

  // MARK: – BGTask registration

  private func registerBackgroundTasks() {
    let identifiers: [String] = [
      "com.personal-ai.tasks.morning_briefing",
      "com.personal-ai.tasks.location_reminder",
      "com.personal-ai.tasks.condition_check",
      "com.personal-ai.tasks.periodic_summary",
    ]
    for identifier in identifiers {
      BGTaskScheduler.shared.register(
        forTaskWithIdentifier: identifier,
        using: nil
      ) { [weak self] task in
        guard let processingTask = task as? BGProcessingTask else {
          task.setTaskCompleted(success: false)
          return
        }
        self?.handleBackgroundTask(task: processingTask)
      }
    }
    // workmanager Flutter plugin registers its own identifier:
    // be.tramckrijte.workmanager.iOSBackgroundTask
    // That is handled automatically by GeneratedPluginRegistrant.
  }

  // MARK: – Method channel setup

  private func setupBackgroundTaskChannel(engineBridge: FlutterImplicitEngineBridge) {
    guard
      let registrar = engineBridge.pluginRegistry.registrar(
        forPlugin: "PersonalAiAssistantBackgroundTasks"
      )
    else { return }

    let channel = FlutterMethodChannel(
      name: "personal_ai_assistant/background_tasks",
      binaryMessenger: registrar.messenger()
    )
    bgMethodChannel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handleMethodCall(call: call, result: result)
    }
  }

  private func handleMethodCall(
    call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    switch call.method {

    case "scheduleTask":
      // Dart-side scheduling for our custom BGTask identifiers.
      // workmanager handles its own scheduling; this path is used for
      // direct native BGProcessingTask submission if needed.
      if let args = call.arguments as? [String: Any],
         let taskId = args["taskId"] as? String
      {
        let request = BGProcessingTaskRequest(identifier: taskId)
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false
        try? BGTaskScheduler.shared.submit(request)
      }
      result(nil)

    case "cancelTask":
      if let args = call.arguments as? [String: Any],
         let taskId = args["taskId"] as? String
      {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: taskId)
      }
      result(nil)

    case "cancelAll":
      BGTaskScheduler.shared.cancelAllTaskRequests()
      result(nil)

    case "isBatteryOptimizationBypassed":
      // iOS has no battery optimisation concept; always report as bypassed.
      result(true)

    case "getNativePendingTasks":
      let pending =
        UserDefaults.standard.stringArray(forKey: "pendingForegroundTasks") ?? []
      result(pending)

    case "clearNativePendingTask":
      if let args = call.arguments as? [String: Any],
         let taskId = args["taskId"] as? String
      {
        var pending =
          UserDefaults.standard.stringArray(forKey: "pendingForegroundTasks") ?? []
        pending.removeAll { $0 == taskId }
        UserDefaults.standard.set(pending, forKey: "pendingForegroundTasks")
      }
      result(nil)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: – BGProcessingTask execution (8.8 time-budget fallback)

  private func handleBackgroundTask(task: BGProcessingTask) {
    // Set the expiration handler first so iOS can call it if time runs out.
    task.expirationHandler = { [weak task] in
      guard let task = task else { return }
      AppDelegate.storePendingForeground(taskId: task.identifier)
      AppDelegate.scheduleTimeBudgetNotification(taskId: task.identifier)
      task.setTaskCompleted(success: false)
    }

    // Proactive time-budget check: if fewer than 3 seconds remain, bail out
    // early and defer to next foreground launch (8.8 fallback).
    let timeRemaining = ProcessInfo.processInfo.backgroundTimeRemaining
    if timeRemaining < 3 {
      AppDelegate.storePendingForeground(taskId: task.identifier)
      AppDelegate.scheduleTimeBudgetNotification(taskId: task.identifier)
      task.setTaskCompleted(success: false)
      return
    }

    guard let channel = bgMethodChannel else {
      // Flutter engine not yet ready; defer to foreground.
      AppDelegate.storePendingForeground(taskId: task.identifier)
      task.setTaskCompleted(success: false)
      return
    }

    channel.invokeMethod("executeTask", arguments: task.identifier) { _ in
      task.setTaskCompleted(success: true)
    }
  }

  // MARK: – Helpers

  private static func storePendingForeground(taskId: String) {
    var pending =
      UserDefaults.standard.stringArray(forKey: "pendingForegroundTasks") ?? []
    if !pending.contains(taskId) {
      pending.append(taskId)
    }
    UserDefaults.standard.set(pending, forKey: "pendingForegroundTasks")
  }

  // Schedule a local notification so the user knows to open the app.
  private static func scheduleTimeBudgetNotification(taskId: String) {
    let content = UNMutableNotificationContent()
    content.title = "任务待处理"
    content.body = "请打开应用以完成待执行的后台任务"
    content.sound = .default

    let trigger = UNTimeIntervalNotificationTrigger(
      timeInterval: 1,
      repeats: false
    )
    let request = UNNotificationRequest(
      identifier: "pending_fallback_\(taskId)",
      content: content,
      trigger: trigger
    )
    UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
  }
}
