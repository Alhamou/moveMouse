import Foundation
import IOKit.pwr_mgt

final class SleepManager {
    static let shared = SleepManager()
    private var assertionID: IOPMAssertionID = 0
    private(set) var isSleepPrevented = false

    private init() {}

    func enableSleepPrevention(reason: String = "MoveMouse Active for RDP") {
        guard !isSleepPrevented else { return }
        let success = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason as CFString,
            &assertionID
        )
        if success == kIOReturnSuccess {
            isSleepPrevented = true
        }
    }

    func disableSleepPrevention() {
        guard isSleepPrevented else { return }
        IOPMAssertionRelease(assertionID)
        assertionID = 0
        isSleepPrevented = false
    }

    deinit {
        disableSleepPrevention()
    }
}
