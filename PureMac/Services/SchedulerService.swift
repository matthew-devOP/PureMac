import Foundation
import Combine

@MainActor
class SchedulerService: ObservableObject {
    @Published var config: ScheduleConfig {
        didSet { saveConfig() }
    }

    private var timer: Timer?
    private let configKey = "PureMac.ScheduleConfig"
    private var onTrigger: (() async -> Void)?

    init() {
        if let data = UserDefaults.standard.data(forKey: configKey),
           let saved = try? JSONDecoder().decode(ScheduleConfig.self, from: data) {
            self.config = saved
        } else {
            self.config = ScheduleConfig()
        }
    }

    func setTrigger(_ handler: @escaping () async -> Void) {
        self.onTrigger = handler
    }

    func start() {
        stop()
        guard config.isEnabled else { return }

        updateNextRunDate()

        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkAndRun()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func updateSchedule(interval: ScheduleInterval) {
        config.interval = interval
        updateNextRunDate()
        if config.isEnabled {
            start()
        }
    }

    func toggleEnabled(_ enabled: Bool) {
        config.isEnabled = enabled
        if enabled {
            start()
        } else {
            stop()
        }
    }

    // MARK: - Private

    private func checkAndRun() {
        guard config.isEnabled,
              let nextRun = config.nextRunDate,
              Date() >= nextRun else { return }

        config.lastRunDate = Date()
        updateNextRunDate()

        Task {
            await onTrigger?()
        }
    }

    private func updateNextRunDate() {
        let base = config.lastRunDate ?? Date()
        config.nextRunDate = base.addingTimeInterval(config.interval.seconds)
    }

    private func saveConfig() {
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: configKey)
        }
    }

    // MARK: - LaunchAgent Management

    func installLaunchAgent() {
        let plistName = "com.puremac.scheduler"
        let plistPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(plistName).plist")

        guard let appPath = Bundle.main.executablePath else { return }

        let intervalSeconds = Int(config.interval.seconds)
        let plistContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(plistName)</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(appPath)</string>
                <string>--scheduled-clean</string>
            </array>
            <key>StartInterval</key>
            <integer>\(intervalSeconds)</integer>
            <key>RunAtLoad</key>
            <false/>
        </dict>
        </plist>
        """

        try? plistContent.write(to: plistPath, atomically: true, encoding: .utf8)

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        task.arguments = ["load", plistPath.path]
        try? task.run()
        task.waitUntilExit()
    }

    func uninstallLaunchAgent() {
        let plistName = "com.puremac.scheduler"
        let plistPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(plistName).plist")

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        task.arguments = ["unload", plistPath.path]
        try? task.run()
        task.waitUntilExit()

        try? FileManager.default.removeItem(at: plistPath)
    }
}
