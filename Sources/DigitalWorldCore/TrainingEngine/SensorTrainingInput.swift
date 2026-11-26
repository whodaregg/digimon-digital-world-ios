import Foundation

public enum SensorTrainingMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case virtual, shake, tilt, walking
    public var id: String { rawValue }
}

/// Emits an input once per gesture and uses only the pedometer's measured step count.
public struct SensorTrainingInput: Sendable {
    private var shakeCounter = MotionInputCounter()
    private var tiltArmed = true
    private var stepMilestones = 0
    public static let stepsPerInput = 10
    public init() {}

    public mutating func shake(x: Double, y: Double, z: Double, time: Double) -> String? {
        guard shakeCounter.sample(x: x, y: y, z: z, time: time) else { return nil }
        return x >= 0 ? "A" : "B"
    }

    public mutating func tilt(gravityX: Double) -> String? {
        guard gravityX.isFinite, (-1.1...1.1).contains(gravityX) else { return nil }
        if abs(gravityX) < 0.20 { tiltArmed = true }
        guard tiltArmed, abs(gravityX) >= 0.52 else { return nil }
        tiltArmed = false
        return gravityX >= 0 ? "A" : "B"
    }

    public mutating func walking(steps: Int, key: String) -> [String] {
        guard steps >= 0, key == "A" || key == "B" else { return [] }
        let reached = min(5, steps / Self.stepsPerInput)
        guard reached > stepMilestones else { return [] }
        let count = reached - stepMilestones
        stepMilestones = reached
        return Array(repeating: key, count: count)
    }
}
