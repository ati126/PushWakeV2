import SwiftUI

private let accent = Color(red: 0.48, green: 0.96, blue: 0.43)

struct HomeView: View {
    @EnvironmentObject private var alarms: AlarmController
    @Environment(\.scenePhase) private var scenePhase
    @State private var workoutOpen = false
    @State private var showingHelp = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack {
                        Image(systemName: "alarm.fill").foregroundStyle(accent)
                        Text("PUSHWAKE").font(.headline).tracking(3)
                        Spacer()
                        Image(systemName: "moon.stars.fill").foregroundStyle(.gray)
                    }
                    .padding(.top, 12)

                    Text("Aufstehen.\nDurchstarten.")
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .minimumScaleFactor(0.7)
                        .tracking(-1.5)

                    VStack(alignment: .leading, spacing: 18) {
                        Label("DEIN NÄCHSTER WECKER", systemImage: "clock")
                            .font(.caption.bold()).foregroundStyle(.gray)
                        HStack(spacing: 8) {
                            Picker("Stunde", selection: $alarms.hour) {
                                ForEach(0..<24) { Text(String(format: "%02d", $0)).tag($0) }
                            }.pickerStyle(.wheel).frame(maxWidth: .infinity)
                            Text(":").font(.largeTitle.bold())
                            Picker("Minute", selection: $alarms.minute) {
                                ForEach(0..<60) { Text(String(format: "%02d", $0)).tag($0) }
                            }.pickerStyle(.wheel).frame(maxWidth: .infinity)
                        }
                        .frame(height: 145).clipped()
                        HStack {
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Liegestütze").font(.title3.bold())
                                Text("Wähle ein angenehmes Ziel").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Stepper("\(alarms.goal)", value: $alarms.goal, in: 1...30)
                                .labelsHidden()
                            Text("\(alarms.goal)").font(.title2.bold()).monospacedDigit()
                        }
                        Text(alarms.status).font(.footnote).foregroundStyle(.secondary)
                        Button {
                            Task { await alarms.save() }
                        } label: {
                            HStack {
                                if alarms.busy { ProgressView().tint(.black) }
                                Image(systemName: "alarm.fill")
                                Text(alarms.hasAlarm ? "Wecker aktualisieren" : "Wecker aktivieren")
                            }
                            .frame(maxWidth: .infinity).padding(16)
                        }
                        .buttonStyle(.plain).font(.headline)
                        .foregroundStyle(.black).background(accent, in: RoundedRectangle(cornerRadius: 16))
                        .disabled(alarms.busy)
                        if alarms.hasAlarm {
                            Button("Wecker löschen", role: .destructive) { alarms.remove() }
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(22)
                    .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 24))

                    VStack(alignment: .leading, spacing: 12) {
                        Label("KAMERA TESTEN", systemImage: "camera.viewfinder")
                            .font(.caption.bold()).foregroundStyle(.gray)
                        Text("Teste die Liegestützerkennung, bevor du dich darauf verlässt.")
                            .foregroundStyle(.secondary)
                        Button("Training starten") { workoutOpen = true }
                            .font(.headline).frame(maxWidth: .infinity).padding(16)
                            .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
                    }
                    .padding(22)
                    .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 24))

                    Text("Hinweis: Die iOS-Systemoberfläche kann den Wecker unabhängig von den Liegestützen stoppen. PushWake benötigt iOS 26 oder neuer.")
                        .font(.caption).foregroundStyle(.gray)
                }
                .padding(22)
            }
            .background(Color(red: 0.055, green: 0.07, blue: 0.08))
            .toolbar(.hidden, for: .navigationBar)
            .fullScreenCover(isPresented: $workoutOpen) { WorkoutView(goal: alarms.goal) }
            .onAppear { checkWorkoutLaunch() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { checkWorkoutLaunch() }
            }
        }
    }

    private func checkWorkoutLaunch() {
        guard UserDefaults.standard.bool(forKey: "openWorkoutRequested") else { return }
        UserDefaults.standard.removeObject(forKey: "openWorkoutRequested")
        workoutOpen = true
    }
}

struct WorkoutView: View {
    @EnvironmentObject private var alarms: AlarmController
    @Environment(\.dismiss) private var dismiss
    @StateObject private var tracker = CameraTracker()
    @State private var completed = false
    let goal: Int

    var body: some View {
        GeometryReader { geometry in
            // Explicit camera height prevents the preview collapsing to a narrow strip.
            let cameraHeight = min(max(geometry.size.height * 0.38, 190), 340)
            ScrollView {
                VStack(spacing: 14) {
                    HStack {
                        Text("PUSHWAKE")
                            .font(.headline)
                            .tracking(2)
                        Spacer()
                        Button("Beenden") { tracker.stop(); dismiss() }
                            .foregroundStyle(.orange)
                    }
                    .padding(.top, 8)

                    Text(completed ? "Geschafft!" : "Liegestütze")
                        .font(.system(size: 29, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white.opacity(0.08))
                        CameraPreview(session: tracker.session)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                        Label("Frontkamera", systemImage: "camera.fill")
                            .font(.caption.bold())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(.black.opacity(0.7), in: Capsule())
                            .padding(12)
                        if !tracker.authorized {
                            Text("Kamerazugriff wird benötigt")
                                .font(.callout)
                                .padding(10)
                                .background(.black.opacity(0.8), in: Capsule())
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                    .frame(height: cameraHeight)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("Live-Vorschau der Frontkamera")

                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text("\(tracker.count)")
                            .font(.system(size: 67, weight: .black, design: .rounded))
                            .foregroundStyle(accent)
                            .contentTransition(.numericText())
                        Text("/ \(goal)")
                            .font(.title2)
                            .foregroundStyle(.gray)
                    }
                    ProgressView(value: Double(min(goal, tracker.count)), total: Double(max(goal, 1)))
                        .tint(accent)

                    Text(tracker.message)
                        .font(.callout)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("iPhone stabil aufstellen und vollständig im Bild bleiben. Die Zahl wird live aktualisiert.")
                        .font(.caption)
                        .foregroundStyle(.gray)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Button(completed ? "Fertig" : "Zähler zurücksetzen") {
                        if completed { tracker.stop(); dismiss() }
                        else { tracker.reset() }
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(15)
                    .foregroundStyle(.black)
                    .background(accent, in: RoundedRectangle(cornerRadius: 16))
                    .padding(.top, 4)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 16)
            }
            .scrollIndicators(.hidden)
            .background(Color.black)
        }
        .onAppear { tracker.start() }
        .onDisappear { tracker.stop() }
        .onChange(of: tracker.count) { _, newCount in
            if newCount >= goal && !completed {
                completed = true
                alarms.finishWorkout()
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
    }
}
