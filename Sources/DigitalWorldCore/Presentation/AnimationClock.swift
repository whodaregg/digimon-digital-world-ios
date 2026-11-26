import Foundation

/// A presentation clock independent of gameplay and RNG. Can be stepped in tests.
public struct SpriteAnimationClock: Equatable, Sendable {
    public private(set) var elapsed: Double = 0
    public init() {}
    public mutating func reset() { elapsed = 0 }
    public mutating func advance(_ seconds: Double) {
        guard seconds.isFinite,seconds >= 0 else { return }
        elapsed += min(seconds,0.25)
    }
    public func index(count: Int,frameSeconds: Double,loops: Bool = true) -> Int {
        guard count > 0,frameSeconds.isFinite,frameSeconds > 0 else { return 0 }
        let frame = Int(elapsed/frameSeconds)
        return loops ? frame % count : min(count-1,frame)
    }
}
public struct AmbientPetPose: Equatable, Sendable {
    public var x: Double
    public var yOffset: Double
    public var facesRight: Bool
    public var action: String
}
public enum AmbientPetTimeline {
    public static func sample(seconds: Double,originX: Double = 0) -> AmbientPetPose {
        let elapsed = max(0,seconds.isFinite ? seconds : 0), t = elapsed.truncatingRemainder(dividingBy: 12)
        if t < 2 { let origin = elapsed < 12 ? min(64,max(-64,originX)) : 0
            return .init(x: origin+(64-origin)*t/2,yOffset: 0,facesRight: true,action: "walk") }
        if t < 3 { return .init(x: 64,yOffset: 0,facesRight: false,action: "idle") }
        if t < 7 { return .init(x: 64-(t-3)*32,yOffset: 0,facesRight: false,action: "walk") }
        if t < 8 { return .init(x: -64,yOffset: sin((t-7)*Double.pi)*10,facesRight: true,action: "happy") }
        if t < 9 { return .init(x: -64,yOffset: 0,facesRight: true,action: "idle") }
        if t < 11 { return .init(x: -64+(t-9)*32,yOffset: 0,facesRight: true,action: "walk") }
        return .init(x: 0,yOffset: 0,facesRight: t < 11.5,action: "idle")
    }
}
