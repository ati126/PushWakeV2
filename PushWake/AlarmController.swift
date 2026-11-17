import SwiftUI
import AlarmKit
import AppIntents

// App Intent for the second button of the system alarm.
struct OpenWorkoutIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Liegestütze starten"
    static var description = IntentDescription("Öffnet PushWake für das Training")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        UserDefaults.standard.set(true, forKey: "openWorkoutRequested")
        return .result()
    }
}

@MainActor
final class AlarmController: ObservableObject {
    @Published var hour: Int = UserDefaults.standard.object(forKey: "hour") as? Int ?? 7
    @Published var minute: Int = UserDefaults.standard.object(forKey: "minute") as? Int ?? 0
    @Published var goal: Int = max(1, UserDefaults.standard.object(forKey: "goal") as? Int ?? 5)
    @Published var status = "Noch kein Wecker aktiviert"
    @Published var hasAlarm = false
    @Published var busy = false

    private let idKey = "scheduledAlarmID"

    init() {
        hasAlarm = UserDefaults.standard.string(forKey: idKey) != nil
        if hasAlarm { status = "Wecker geplant – über iOS verwaltet" }
    }

    func save() async {
        busy = true
        defer { busy = false }
        do {
            // Never remove the previous alarm before we know access is granted.
            let authorization = try await AlarmManager.shared.requestAuthorization()
            guard AlarmManager.shared.authorizationState == .authorized else {
                status = "Alarm-Berechtigung fehlt (Status: \(String(describing: authorization))). In iOS-Einstellungen erlauben."
                return
            }
            if let old = savedID { try? AlarmManager.shared.cancel(id: old) }
            let id = UUID()
            let time = Alarm.Schedule.Relative.Time(hour: hour, minute: minute)
            let schedule = Alarm.Schedule.relative(.init(time: time, repeats: .never))
            let alert = AlarmPresentation.Alert(
                title: "Zeit für deine Liegestütze!",
                stopButton: AlarmButton(text: "Stoppen", textColor: .white, systemImageName: "stop.circle"),
                secondaryButton: AlarmButton(text: "Training", textColor: .white, systemImageName: "figure.strengthtraining.traditional"),
                secondaryButtonBehavior: .custom
            )
            let attributes = AlarmAttributes<EmptyAlarmMetadata>(
                presentation: AlarmPresentation(alert: alert),
                metadata: EmptyAlarmMetadata(),
                tintColor: .green
            )
            let config: AlarmManager.AlarmConfiguration<EmptyAlarmMetadata> = .alarm(
                schedule: schedule,
                attributes: attributes,
                stopIntent: nil,
                secondaryIntent: OpenWorkoutIntent(),
                sound: .default
            )
            _ = try await AlarmManager.shared.schedule(id: id, configuration: config)
            UserDefaults.standard.set(id.uuidString, forKey: idKey)
            UserDefaults.standard.set(hour, forKey: "hour")
            UserDefaults.standard.set(minute, forKey: "minute")
            UserDefaults.standard.set(goal, forKey: "goal")
            hasAlarm = true
            status = String(format: "Wecker auf %02d:%02d gestellt", hour, minute)
        } catch {
            let nsError = error as NSError
            status = "Alarm fehlgeschlagen: \(nsError.domain), Code \(nsError.code) – \(nsError.localizedDescription)"
            hasAlarm = savedID != nil
        }
    }

    func remove() {
        guard let id = savedID else { return }
        do {
            try AlarmManager.shared.cancel(id: id)
            clearLocalAlarm()
            status = "Wecker deaktiviert"
        } catch {
            status = "Abbrechen fehlgeschlagen: \(error.localizedDescription)"
        }
    }

    func finishWorkout() {
        // Cancel is a supported manual stop for an alarm; it also removes the scheduled entry.
        if let id = savedID {
            try? AlarmManager.shared.cancel(id: id)
            clearLocalAlarm()
            status = "Training abgeschlossen!"
        }
    }

    private var savedID: UUID? {
        UserDefaults.standard.string(forKey: idKey).flatMap(UUID.init(uuidString:))
    }
    private func clearLocalAlarm() {
        UserDefaults.standard.removeObject(forKey: idKey)
        hasAlarm = false
    }
}

struct EmptyAlarmMetadata: AlarmMetadata { }
