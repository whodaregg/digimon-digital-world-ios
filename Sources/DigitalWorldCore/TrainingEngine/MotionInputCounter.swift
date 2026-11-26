import Foundation

/// Phone input assistance only; this is not a claim about a physical Pendulum's sensor firmware.
public struct MotionInputCounter: Sendable {
    public private(set) var count = 0
    private var armed = true
    private var lastPulse = -Double.greatestFiniteMagnitude
    public init() {}
    @discardableResult public mutating func sample(x: Double,y: Double,z: Double,time: Double) -> Bool {
        guard [x,y,z,time].allSatisfy(\.isFinite),time >= lastPulse else { return false }
        let magnitude = sqrt(x*x+y*y+z*z)
        if magnitude < 1.2 { armed = true }
        guard armed,magnitude > 1.8,time-lastPulse >= 0.3 else { return false }
        armed = false; lastPulse = time; count += 1; return true
    }
}
