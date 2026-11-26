import SwiftUI
import DigitalWorldCore

struct DeviceHardwareKey: UIViewRepresentable {
    let key: DeviceKey
    let model: WorldViewModel
    func makeUIView(context: Context) -> DeviceKeyControl {
        let view = DeviceKeyControl(); configure(view); return view
    }
    func updateUIView(_ uiView: DeviceKeyControl,context: Context) { configure(uiView) }
    private func configure(_ view: DeviceKeyControl) {
        view.setTitle(key.rawValue,for: .normal)
        view.accessibilityIdentifier = "hardware-\(key.rawValue)"
        view.accessibilityLabel = "\(key.rawValue)键"
        view.onDown = { model.lcdKeyDown(key) }; view.onUp = { model.lcdKeyUp(key) }
    }
}
final class DeviceKeyControl: UIButton {
    var onDown: (() -> Void)?, onUp: (() -> Void)?
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(red: 0.77,green: 0.69,blue: 0.52,alpha: 1)
        setTitleColor(.black,for: .normal); titleLabel?.font = UIFont(name: PixelFont.name(.english),size: 18)
        layer.cornerRadius = 14; layer.borderWidth = 2; layer.borderColor = UIColor.black.withAlphaComponent(0.5).cgColor
        isExclusiveTouch = false; isMultipleTouchEnabled = true
        addTarget(self,action: #selector(down),for: .touchDown)
        addTarget(self,action: #selector(up),for: [.touchUpInside,.touchUpOutside,.touchCancel])
    }
    required init?(coder: NSCoder) { fatalError("Storyboard initialization is not supported") }
    @objc private func down() { transform = .init(translationX: 0,y: 2); alpha = 0.7; onDown?() }
    @objc private func up() { transform = .identity; alpha = 1; onUp?() }
    override func accessibilityActivate() -> Bool { down(); up(); return true }
}
