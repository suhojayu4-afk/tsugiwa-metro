import AVFoundation
import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let ok = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    // Set before launch finishes so a tap that started the app is delivered.
    TsugiwaNative.shared.installNoticeDelegate()
    return ok
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "TsugiwaNative") {
      TsugiwaNative.shared.attach(registrar)
    }
  }
}

/// The iPhone side of the app's own channels; names, methods and arguments
/// are the same as android/.../MainActivity.kt so the Dart side is shared.
///
///  - "tsugiwa/live": lastTrainAlarm / lastTrainAlarmOff / ensureNotificationPermission
///    (終電アラーム daily, 始発アラーム once; local notifications at a clock time
///    in Japan). The lock-screen trip methods are not on iPhone yet.
///  - "tsugiwa/sound": play / stop (departure melodies, arrival sound).
///  - "tsugiwa/monthly": schedule / cancel / takeOpenMy, and "openMy" back to
///    Dart when the 月間乗車レポート notice is tapped.
final class TsugiwaNative: NSObject, UNUserNotificationCenterDelegate {
  static let shared = TsugiwaNative()

  private static let monthlyId = "tsugiwa.monthly"
  private static let reportHour = 9

  private let tokyo: TimeZone =
    TimeZone(identifier: "Asia/Tokyo") ?? TimeZone(secondsFromGMT: 9 * 3600) ?? TimeZone.current
  private var registrar: FlutterPluginRegistrar?
  private var monthlyChannel: FlutterMethodChannel?
  private var player: AVAudioPlayer?
  private var openMyPending = false

  private var center: UNUserNotificationCenter { UNUserNotificationCenter.current() }

  private var tokyoCalendar: Calendar {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = tokyo
    return cal
  }

  private static func alarmId(_ slot: String) -> String {
    return slot == "first" ? "tsugiwa.alarm.first" : "tsugiwa.alarm.last"
  }

  func installNoticeDelegate() {
    center.delegate = self
  }

  func attach(_ registrar: FlutterPluginRegistrar) {
    self.registrar = registrar
    let messenger = registrar.messenger()

    let live = FlutterMethodChannel(name: "tsugiwa/live", binaryMessenger: messenger)
    live.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(FlutterMethodNotImplemented)
        return
      }
      self.handleLive(call, result: result)
    }

    let sound = FlutterMethodChannel(name: "tsugiwa/sound", binaryMessenger: messenger)
    sound.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(FlutterMethodNotImplemented)
        return
      }
      self.handleSound(call, result: result)
    }

    let monthly = FlutterMethodChannel(name: "tsugiwa/monthly", binaryMessenger: messenger)
    monthlyChannel = monthly
    monthly.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(FlutterMethodNotImplemented)
        return
      }
      self.handleMonthly(call, result: result)
    }
  }

  // MARK: - tsugiwa/live (train alarms)

  private func handleLive(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "lastTrainAlarm":
      let slot = args["slot"] as? String ?? "last"
      let minute = (args["minute"] as? NSNumber)?.intValue ?? 0
      let title = args["title"] as? String ?? ""
      let text = args["text"] as? String ?? ""
      // Asked here, when an alarm is turned on (never at launch). After the
      // first answer iOS does not ask again.
      center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in
        DispatchQueue.main.async {
          self.scheduleAlarm(slot: slot, minute: minute, title: title, text: text)
          result(nil)
        }
      }
    case "lastTrainAlarmOff":
      let slot = args["slot"] as? String ?? "last"
      center.removePendingNotificationRequests(withIdentifiers: [TsugiwaNative.alarmId(slot)])
      result(nil)
    case "ensureNotificationPermission":
      // Only reports; the question itself comes with lastTrainAlarm.
      center.getNotificationSettings { settings in
        let status = settings.authorizationStatus
        let ok = status == .authorized || status == .provisional || status == .ephemeral
        DispatchQueue.main.async { result(ok) }
      }
    default:
      // start / update / alert / end: lock-screen trip view, not on iPhone yet.
      result(FlutterMethodNotImplemented)
    }
  }

  /// "last" repeats every day at [minute] (Japan clock time, 0..1439);
  /// "first" rings once at its next coming. The same slot replaces itself.
  private func scheduleAlarm(slot: String, minute: Int, title: String, text: String) {
    let id = TsugiwaNative.alarmId(slot)
    center.removePendingNotificationRequests(withIdentifiers: [id])

    let cal = tokyoCalendar
    let now = Date()
    let m = ((minute % 1440) + 1440) % 1440
    var comps = cal.dateComponents([.year, .month, .day], from: now)
    comps.hour = m / 60
    comps.minute = m % 60
    comps.second = 0
    guard var fire = cal.date(from: comps) else { return }
    if fire.timeIntervalSince(now) <= 1 {
      guard let next = cal.date(byAdding: .day, value: 1, to: fire) else { return }
      fire = next
    }

    let content = UNMutableNotificationContent()
    content.title = title
    content.body = text
    content.sound = UNNotificationSound.default
    content.threadIdentifier = "tsugiwa.alarm"

    let trigger: UNNotificationTrigger
    if slot == "first" {
      trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, fire.timeIntervalSince(now)), repeats: false)
    } else {
      // The phone's own clock time for that moment (the same in Japan).
      let local = Calendar.current.dateComponents([.hour, .minute], from: fire)
      trigger = UNCalendarNotificationTrigger(dateMatching: local, repeats: true)
    }
    let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
    center.add(request) { _ in }
  }

  // MARK: - tsugiwa/sound

  private func handleSound(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "play":
      let args = call.arguments as? [String: Any] ?? [:]
      guard let asset = args["asset"] as? String else {
        result(nil)
        return
      }
      let force = (args["force"] as? Bool) ?? false
      do {
        try play(asset: asset, force: force)
        result(nil)
      } catch {
        result(FlutterError(code: "sound", message: error.localizedDescription, details: nil))
      }
    case "stop":
      stopSound()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// Plays a Flutter asset. Polite like Android: "ambient" is muted by the
  /// silent switch; a preview the user asked for ([force]) plays anyway.
  private func play(asset: String, force: Bool) throws {
    stopSound()
    guard let registrar = registrar else { return }
    let key = registrar.lookupKey(forAsset: asset)
    guard let path = Bundle.main.path(forResource: key, ofType: nil) else { return }
    let session = AVAudioSession.sharedInstance()
    if force {
      try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
    } else {
      try session.setCategory(.ambient, mode: .default, options: [])
    }
    try session.setActive(true)
    let p = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: path))
    p.prepareToPlay()
    p.play()
    player = p
  }

  private func stopSound() {
    player?.stop()
    player = nil
  }

  // MARK: - tsugiwa/monthly (月間乗車レポート)

  private func handleMonthly(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "schedule":
      let months = args["months"] as? [String] ?? []
      let titles = args["titles"] as? [String] ?? []
      let text = args["text"] as? String ?? ""
      scheduleMonthly(months: months, titles: titles, text: text)
      result(nil)
    case "cancel":
      center.removePendingNotificationRequests(withIdentifiers: [TsugiwaNative.monthlyId])
      result(nil)
    case "takeOpenMy":
      let open = openMyPending
      openMyPending = false
      result(open)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// The next 1st of a month, 9:00 in Tokyo, only when the month before it
  /// had a ride. Dart sends this again on every start and trip-log change,
  /// so the following month is set while the user is riding. Never asks
  /// for permission itself (that comes with the train alarms).
  private func scheduleMonthly(months: [String], titles: [String], text: String) {
    center.removePendingNotificationRequests(withIdentifiers: [TsugiwaNative.monthlyId])

    let cal = tokyoCalendar
    let now = Date()
    var comps = cal.dateComponents([.year, .month], from: now)
    comps.day = 1
    comps.hour = TsugiwaNative.reportHour
    comps.minute = 0
    comps.second = 0
    guard var at = cal.date(from: comps) else { return }
    if at.timeIntervalSince(now) <= 1 {
      guard let next = cal.date(byAdding: .month, value: 1, to: at) else { return }
      at = next
    }
    guard let prev = cal.date(byAdding: .month, value: -1, to: at) else { return }
    let year = cal.component(.year, from: prev)
    let month = cal.component(.month, from: prev)
    let key = "\(year)-" + (month < 10 ? "0\(month)" : "\(month)")
    guard months.contains(key), month >= 1, month <= titles.count else { return }

    let content = UNMutableNotificationContent()
    content.title = titles[month - 1]
    content.body = text
    content.sound = UNNotificationSound.default
    content.threadIdentifier = "tsugiwa.monthly"

    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, at.timeIntervalSince(now)), repeats: false)
    let request = UNNotificationRequest(identifier: TsugiwaNative.monthlyId, content: content, trigger: trigger)
    center.add(request) { _ in }
  }

  /// The monthly notice was tapped: open MY now if Dart is listening,
  /// otherwise when it asks with "takeOpenMy".
  private func openMy() {
    openMyPending = true
    guard let channel = monthlyChannel else { return }
    channel.invokeMethod("openMy", arguments: nil) { [weak self] reply in
      // No Dart handler yet (cold start): leave it for "takeOpenMy".
      if let r = reply as? NSObject, r === FlutterMethodNotImplemented { return }
      self?.openMyPending = false
    }
  }

  // MARK: - UNUserNotificationCenterDelegate

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    // Show the alarms even while the app is open.
    completionHandler([.banner, .list, .sound])
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    if response.notification.request.identifier == TsugiwaNative.monthlyId {
      DispatchQueue.main.async { self.openMy() }
    }
    completionHandler()
  }
}
