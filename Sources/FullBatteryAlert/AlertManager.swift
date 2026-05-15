import Foundation

enum AlertEvent {
    case highThreshold(Int)
    case lowThreshold(Int)
    case powerCut
    case powerRestored
}

final class AlertManager {
    static let shared = AlertManager()

    private var firedThresholds: Set<Int> = []
    private var firedLowThresholds: Set<Int> = []
    private var lastPluggedIn: Bool? = nil
    private init() {}

    func handleUpdate(percentage: Int, isCharging: Bool, isPluggedIn: Bool,
                      settings: AppSettings,
                      onFire: (AlertEvent) -> Void) {
        // Detect plug-state transitions.
        if let prev = lastPluggedIn, prev != isPluggedIn {
            if !isPluggedIn, settings.alertOnPowerCut {
                onFire(.powerCut)
            } else if isPluggedIn, settings.alertOnPowerRestored {
                onFire(.powerRestored)
            }
        }
        lastPluggedIn = isPluggedIn

        // High thresholds: only while plugged in. Reset when unplugged or below
        // the lowest high threshold.
        if !isPluggedIn || percentage < (settings.thresholds.min() ?? 0) {
            firedThresholds.removeAll()
        } else {
            for threshold in settings.thresholds.sorted() {
                if percentage >= threshold && !firedThresholds.contains(threshold) {
                    firedThresholds.insert(threshold)
                    onFire(.highThreshold(threshold))
                }
            }
        }

        // Low thresholds: only while on battery. Reset when plugged in or above
        // the highest low threshold.
        if isPluggedIn || percentage > (settings.lowThresholds.max() ?? 100) {
            firedLowThresholds.removeAll()
        } else {
            for threshold in settings.lowThresholds.sorted(by: >) {
                if percentage <= threshold && !firedLowThresholds.contains(threshold) {
                    firedLowThresholds.insert(threshold)
                    onFire(.lowThreshold(threshold))
                }
            }
        }
    }
}
