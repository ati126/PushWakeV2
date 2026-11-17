import Foundation
import Vision
import CoreGraphics

/// Simple elbow-angle push-up heuristic. Requires a side view with elbow visible.
/// Count a rep only after a down -> up transition to avoid counting jitter.
struct PushupCounter {
    enum Phase { case unknown, up, down }
    private(set) var count = 0
    private(set) var phase: Phase = .unknown
    private var candidate: Phase = .unknown
    private var stableFrames = 0
    private var lastRepTime: TimeInterval = 0

    mutating func reset() {
        count = 0; phase = .unknown; candidate = .unknown
        stableFrames = 0; lastRepTime = 0
    }

    mutating func ingest(_ pose: VNHumanBodyPoseObservation, now: TimeInterval) -> (Int, String) {
        guard let angle = elbowAngle(pose) else { return (count, "Seitlich positionieren – Arm vollständig sichtbar") }
        let detected: Phase
        if angle >= 145 { detected = .up }
        else if angle <= 110 { detected = .down }
        else { detected = .unknown }

        guard detected != .unknown else {
            candidate = .unknown; stableFrames = 0
            return (count, "Bewegung fortsetzen")
        }
        if candidate == detected { stableFrames += 1 }
        else { candidate = detected; stableFrames = 1 }

        if stableFrames >= 3 && phase != detected {
            if phase == .down && detected == .up && now - lastRepTime >= 0.7 {
                count += 1
                lastRepTime = now
            }
            phase = detected
        }
        return (count, "Armwinkel: \(Int(angle.rounded()))° · " + (phase == .down ? "Jetzt hochdrücken" : "Jetzt kontrolliert absenken"))
    }

    private func elbowAngle(_ pose: VNHumanBodyPoseObservation) -> Double? {
        typealias Joint = VNHumanBodyPoseObservation.JointName
        let sides: [(Joint, Joint, Joint)] = [
            (.leftShoulder, .leftElbow, .leftWrist),
            (.rightShoulder, .rightElbow, .rightWrist)
        ]
        guard let points = try? pose.recognizedPoints(.all) else { return nil }
        var bestAngle: Double?
        var bestConfidence: Float = 0
        for (shoulder, elbow, wrist) in sides {
            guard let s = points[shoulder], let e = points[elbow], let w = points[wrist] else { continue }
            let confidence = min(s.confidence, e.confidence, w.confidence)
            guard confidence >= 0.25 else { continue }
            let ax = Double(s.location.x - e.location.x), ay = Double(s.location.y - e.location.y)
            let bx = Double(w.location.x - e.location.x), by = Double(w.location.y - e.location.y)
            let denominator = hypot(ax, ay) * hypot(bx, by)
            guard denominator > 0.0001 else { continue }
            let cosine = max(-1.0, min(1.0, (ax * bx + ay * by) / denominator))
            if confidence > bestConfidence {
                bestConfidence = confidence
                bestAngle = acos(cosine) * 180 / .pi
            }
        }
        return bestAngle
    }
}
