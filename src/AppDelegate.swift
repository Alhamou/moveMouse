import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let menu = NSMenu()
    private let mover = MouseMover.shared

    // Menu Items references
    private var statusHeaderItem: NSMenuItem!
    private var lastMovedItem: NSMenuItem!
    private var toggleItem: NSMenuItem!
    private var moveNowItem: NSMenuItem!
    private var intervalMenu: NSMenu!
    private var modeMenu: NSMenu!
    private var clickToggleItem: NSMenuItem!
    private var soundToggleItem: NSMenuItem!
    private var accessibilityItem: NSMenuItem!

    private var lastMovedDate: Date?
    private var lastMovedHadClick: Bool = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupMenu()

        mover.onStatusChanged = { [weak self] _ in
            self?.updateUI()
        }

        mover.onMoved = { [weak self] date, didClick in
            self?.lastMovedDate = date
            self?.lastMovedHadClick = didClick
            self?.updateLastMovedLabel()
        }

        // Auto start on launch
        mover.start()
        updateUI()

        // Check accessibility
        if !MouseMover.isAccessibilityGranted(prompt: false) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                _ = MouseMover.isAccessibilityGranted(prompt: true)
            }
        }
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "cursorarrow.motionlines", accessibilityDescription: "MoveMouse")
            button.image?.isTemplate = true
            button.toolTip = "MoveMouse - لمنع انقطاع اتصال RDP"
        }
    }

    private func setupMenu() {
        menu.delegate = self
        menu.autoenablesItems = false

        // 1. Status Header
        statusHeaderItem = NSMenuItem(title: "● الحالة: قيد التشغيل", action: nil, keyEquivalent: "")
        statusHeaderItem.isEnabled = false
        menu.addItem(statusHeaderItem)

        lastMovedItem = NSMenuItem(title: "آخر عملية: لم يتم بعد", action: nil, keyEquivalent: "")
        lastMovedItem.isEnabled = false
        menu.addItem(lastMovedItem)

        menu.addItem(NSMenuItem.separator())

        // 2. Start / Stop Button
        toggleItem = NSMenuItem(title: "⏸ إيقاف مؤقت (Pause)", action: #selector(toggleAction), keyEquivalent: "s")
        toggleItem.target = self
        menu.addItem(toggleItem)

        // 3. Move Now Button
        moveNowItem = NSMenuItem(title: "⚡ تحريك الماوس الآن (Move Now)", action: #selector(moveNowAction), keyEquivalent: "m")
        moveNowItem.target = self
        menu.addItem(moveNowItem)

        menu.addItem(NSMenuItem.separator())

        // 4. Interval Submenu
        let intervalSubmenuItem = NSMenuItem(title: "⏱ الفاصل الزمني (Interval)", action: nil, keyEquivalent: "")
        intervalMenu = NSMenu()
        let intervals: [(String, TimeInterval)] = [
            ("15 ثانية", 15.0),
            ("30 ثانية (الموصى به)", 30.0),
            ("45 ثانية", 45.0),
            ("1 دقيقة (60 ثانية)", 60.0),
            ("2 دقيقة", 120.0),
            ("5 دقائق", 300.0)
        ]

        for (title, sec) in intervals {
            let item = NSMenuItem(title: title, action: #selector(selectIntervalAction(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = sec
            intervalMenu.addItem(item)
        }
        intervalSubmenuItem.submenu = intervalMenu
        menu.addItem(intervalSubmenuItem)

        // 5. Movement Mode Submenu
        let modeSubmenuItem = NSMenuItem(title: "🎯 نمط التحريك (Pattern)", action: nil, keyEquivalent: "")
        modeMenu = NSMenu()
        let centerModeItem = NSMenuItem(title: "منتصف الشاشة (يمين ثم يسار)", action: #selector(selectModeAction(_:)), keyEquivalent: "")
        centerModeItem.target = self
        centerModeItem.representedObject = MovementMode.center
        modeMenu.addItem(centerModeItem)

        let currentModeItem = NSMenuItem(title: "الموضع الحالي للماوس (هزة خفيفة)", action: #selector(selectModeAction(_:)), keyEquivalent: "")
        currentModeItem.target = self
        currentModeItem.representedObject = MovementMode.current
        modeMenu.addItem(currentModeItem)

        modeSubmenuItem.submenu = modeMenu
        menu.addItem(modeSubmenuItem)

        menu.addItem(NSMenuItem.separator())

        // 6. Optional Left Click after move
        clickToggleItem = NSMenuItem(
            title: "🖱️ نقرة بالزر الأيسر بعد الحركة (Left Click)",
            action: #selector(toggleClickAction),
            keyEquivalent: "c"
        )
        clickToggleItem.target = self
        clickToggleItem.state = mover.isClickEnabled ? .on : .off
        menu.addItem(clickToggleItem)

        // 7. Sound feedback toggle
        soundToggleItem = NSMenuItem(
            title: "🔊 صوت نقرة للتأكيد (Click Sound)",
            action: #selector(toggleSoundAction),
            keyEquivalent: ""
        )
        soundToggleItem.target = self
        soundToggleItem.state = mover.isSoundEnabled ? .on : .off
        menu.addItem(soundToggleItem)

        menu.addItem(NSMenuItem.separator())

        // 8. Accessibility Permission Item
        accessibilityItem = NSMenuItem(title: "صلاحية إمكانية الوصول...", action: #selector(accessibilityAction), keyEquivalent: "")
        accessibilityItem.target = self
        menu.addItem(accessibilityItem)

        menu.addItem(NSMenuItem.separator())

        // 9. Quit Button
        let quitItem = NSMenuItem(title: "إغلاق التطبيق (Quit)", action: #selector(quitAction), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    func menuWillOpen(_ menu: NSMenu) {
        updateUI()
        updateIntervalCheckmarks()
        updateModeCheckmarks()
        updateClickToggleCheckmark()
        updateAccessibilityItem()
    }

    private func updateUI() {
        let isRunning = mover.isRunning
        let intervalSec = Int(mover.interval)

        if let button = statusItem.button {
            if isRunning {
                button.image = NSImage(systemSymbolName: "cursorarrow.motionlines", accessibilityDescription: "MoveMouse Active")
                button.toolTip = "MoveMouse: قيد التشغيل (كل \(intervalSec) ثانية)"
            } else {
                button.image = NSImage(systemSymbolName: "cursorarrow.slash", accessibilityDescription: "MoveMouse Paused")
                button.toolTip = "MoveMouse: متوقف مؤقتاً"
            }
            button.image?.isTemplate = true
        }

        if isRunning {
            statusHeaderItem.title = "● الحالة: قيد التشغيل (كل \(intervalSec) ثانية)"
            toggleItem.title = "⏸ إيقاف مؤقت (Pause)"
        } else {
            statusHeaderItem.title = "○ الحالة: متوقف مؤقتاً"
            toggleItem.title = "▶️ بدء التشغيل (Start)"
        }
    }

    private func updateLastMovedLabel() {
        guard let date = lastMovedDate else { return }
        let formatter = DateFormatter()
        formatter.dateFormat = "hh:mm:ss a"
        let timeStr = formatter.string(from: date)
        if lastMovedHadClick {
            lastMovedItem.title = "آخر عملية: \(timeStr) (حركة + نقر ✓)"
        } else {
            lastMovedItem.title = "آخر عملية: \(timeStr) (حركة فقط)"
        }
    }

    private func updateIntervalCheckmarks() {
        for item in intervalMenu.items {
            if let sec = item.representedObject as? TimeInterval {
                item.state = (abs(sec - mover.interval) < 0.1) ? .on : .off
            }
        }
    }

    private func updateModeCheckmarks() {
        for item in modeMenu.items {
            if let mode = item.representedObject as? MovementMode {
                item.state = (mode == mover.mode) ? .on : .off
            }
        }
    }

    private func updateClickToggleCheckmark() {
        clickToggleItem.state = mover.isClickEnabled ? .on : .off
        soundToggleItem.state = mover.isSoundEnabled ? .on : .off
        soundToggleItem.isHidden = !mover.isClickEnabled
    }

    private func updateAccessibilityItem() {
        let granted = MouseMover.isAccessibilityGranted(prompt: false)
        if granted {
            accessibilityItem.title = "✓ صلاحية التحكم والنقر مفعلة بنجاح"
            accessibilityItem.isEnabled = false
        } else {
            accessibilityItem.title = "⚠️ مطلوب منح إذن Accessibility لتعمل النقرة..."
            accessibilityItem.isEnabled = true
        }
    }

    @objc private func toggleAction() {
        mover.toggle()
        updateUI()
    }

    @objc private func moveNowAction() {
        mover.performMoveNow()
    }

    @objc private func selectIntervalAction(_ sender: NSMenuItem) {
        if let sec = sender.representedObject as? TimeInterval {
            mover.interval = sec
            updateUI()
            updateIntervalCheckmarks()
        }
    }

    @objc private func selectModeAction(_ sender: NSMenuItem) {
        if let mode = sender.representedObject as? MovementMode {
            mover.mode = mode
            updateModeCheckmarks()
        }
    }

    @objc private func toggleClickAction() {
        mover.isClickEnabled.toggle()
        updateClickToggleCheckmark()
    }

    @objc private func toggleSoundAction() {
        mover.isSoundEnabled.toggle()
        soundToggleItem.state = mover.isSoundEnabled ? .on : .off
    }

    @objc private func accessibilityAction() {
        _ = MouseMover.isAccessibilityGranted(prompt: true)
        MouseMover.openAccessibilitySettings()

        let alert = NSAlert()
        alert.messageText = "تفعيل إذن التحكم بالماوس (Accessibility)"
        alert.informativeText = "إذا كان المفتاح مفعلاً مسبقاً، يرجى إيقافه ثم إعادة تفعيله مرة أخرى، أو إعادة تشغيل MoveMouse لتتعرف macOS على الإذن الجديد."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "حسناً")
        alert.runModal()
    }

    @objc private func quitAction() {
        mover.stop()
        NSApp.terminate(nil)
    }
}
