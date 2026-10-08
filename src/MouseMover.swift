import Cocoa
import CoreGraphics
import ApplicationServices

enum MovementMode: String, CaseIterable {
    case center = "center"
    case current = "current"
    
    var titleArabic: String {
        switch self {
        case .center:
            return "في منتصف الشاشة (يمين ثم يسار)"
        case .current:
            return "في الموضع الحالي للماوس"
        }
    }
}

final class MouseMover {
    static let shared = MouseMover()

    private var timer: Timer?
    private(set) var isRunning: Bool = false
    var interval: TimeInterval = 30.0 {
        didSet {
            UserDefaults.standard.set(interval, forKey: "move_interval")
            if isRunning {
                restartTimer()
            }
        }
    }

    var mode: MovementMode = .center {
        didSet {
            UserDefaults.standard.set(mode.rawValue, forKey: "movement_mode")
        }
    }

    var isClickEnabled: Bool = true {
        didSet {
            UserDefaults.standard.set(isClickEnabled, forKey: "click_after_move")
        }
    }

    var isSoundEnabled: Bool = true {
        didSet {
            UserDefaults.standard.set(isSoundEnabled, forKey: "sound_on_click")
        }
    }

    var onStatusChanged: ((Bool) -> Void)?
    var onMoved: ((Date, Bool) -> Void)? // Date, didClick

    private init() {
        let savedInterval = UserDefaults.standard.double(forKey: "move_interval")
        if savedInterval >= 5.0 {
            self.interval = savedInterval
        } else {
            self.interval = 30.0
        }

        if let savedModeStr = UserDefaults.standard.string(forKey: "movement_mode"),
           let savedMode = MovementMode(rawValue: savedModeStr) {
            self.mode = savedMode
        } else {
            self.mode = .center
        }

        if UserDefaults.standard.object(forKey: "click_after_move") != nil {
            self.isClickEnabled = UserDefaults.standard.bool(forKey: "click_after_move")
        } else {
            self.isClickEnabled = true
        }

        if UserDefaults.standard.object(forKey: "sound_on_click") != nil {
            self.isSoundEnabled = UserDefaults.standard.bool(forKey: "sound_on_click")
        } else {
            self.isSoundEnabled = true
        }
    }

    static func isAccessibilityGranted(prompt: Bool = false) -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        SleepManager.shared.enableSleepPrevention()
        startTimer()
        onStatusChanged?(true)
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        stopTimer()
        SleepManager.shared.disableSleepPrevention()
        onStatusChanged?(false)
    }

    func toggle() {
        if isRunning {
            stop()
        } else {
            start()
        }
    }

    private func startTimer() {
        timer?.invalidate()
        let t = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            self?.performMove()
        }
        RunLoop.main.add(t, forMode: .common)
        self.timer = t
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func restartTimer() {
        stopTimer()
        if isRunning {
            startTimer()
        }
    }

    func performMoveNow() {
        performMove()
    }

    private func performMove() {
        let currentMode = self.mode
        let click = self.isClickEnabled
        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            switch currentMode {
            case .center:
                self?.moveCenterWiggle(clickAfter: click)
            case .current:
                self?.moveCurrentPositionWiggle(clickAfter: click)
            }

            DispatchQueue.main.async {
                self?.onMoved?(Date(), click)
            }
        }
    }

    private func moveCenterWiggle(clickAfter: Bool) {
        guard let screen = NSScreen.main else { return }
        let primaryHeight = CGFloat(CGDisplayPixelsHigh(CGMainDisplayID()))
        let centerX = screen.frame.midX
        let centerY = primaryHeight - screen.frame.midY

        let center = CGPoint(x: centerX, y: centerY)
        let right = CGPoint(x: centerX + 35.0, y: centerY)
        let left = CGPoint(x: centerX - 35.0, y: centerY)

        applyPoint(center)
        usleep(100_000)
        applyPoint(right)
        usleep(100_000)
        applyPoint(left)
        usleep(100_000)
        applyPoint(center)

        if clickAfter {
            usleep(150_000) // Allow cursor to settle
            performClick(at: center)
        }
    }

    private func moveCurrentPositionWiggle(clickAfter: Bool) {
        let mouseLoc = NSEvent.mouseLocation
        let primaryHeight = CGFloat(CGDisplayPixelsHigh(CGMainDisplayID()))
        let currentY = primaryHeight - mouseLoc.y
        let currentX = mouseLoc.x

        let center = CGPoint(x: currentX, y: currentY)
        let right = CGPoint(x: currentX + 15.0, y: currentY)
        let left = CGPoint(x: currentX - 15.0, y: currentY)

        applyPoint(right)
        usleep(100_000)
        applyPoint(left)
        usleep(100_000)
        applyPoint(center)

        if clickAfter {
            usleep(150_000)
            performClick(at: center)
        }
    }

    private func applyPoint(_ point: CGPoint) {
        CGWarpMouseCursorPosition(point)
        if let event = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left) {
            event.post(tap: .cghidEventTap)
        }
    }

    private func performClick(at point: CGPoint) {
        CGWarpMouseCursorPosition(point)
        usleep(30_000)

        guard let mouseDown = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left),
              let mouseUp = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left) else {
            return
        }

        // Setting clickState to 1 is mandatory for macOS & RDP clients to register a click
        mouseDown.setIntegerValueField(.mouseEventClickState, value: 1)
        mouseUp.setIntegerValueField(.mouseEventClickState, value: 1)

        mouseDown.post(tap: .cghidEventTap)
        usleep(60_000) // 60ms hold duration
        mouseUp.post(tap: .cghidEventTap)

        if isSoundEnabled {
            DispatchQueue.main.async {
                NSSound(named: "Tink")?.play()
            }
        }
    }
}
