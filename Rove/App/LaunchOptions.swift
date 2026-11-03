import CoreGraphics
import Foundation

/// Settings the automatic checks pass when they launch the app, so every
/// run starts from the same sample trips. Normal launches use none.
struct LaunchOptions {
    /// Start from the sample data and save nothing.
    var inMemory = false
    /// Which of Trips, Groups or You to start on.
    var section: String?
    /// Draw the screen at another phone's size (in points), shrunk to fit,
    /// e.g. "-previewSize 951x669" for the open iPhone Duo.
    var previewSize: CGSize?
    /// Open the first trip whose name starts with this, e.g. "Nashville".
    var openTrip: String?
    /// Which part of that trip to show: overview, plan, expenses or balances.
    var tab: String?

    static let current = LaunchOptions(arguments: ProcessInfo.processInfo.arguments)

    init(arguments: [String] = []) {
        func value(after flag: String) -> String? {
            guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else { return nil }
            return arguments[index + 1]
        }
        inMemory = arguments.contains("-uiTesting")
        section = value(after: "-section")
        openTrip = value(after: "-openTrip")
        tab = value(after: "-tab")
        if arguments.contains("-openDuoPreview") {
            previewSize = CGSize(width: 951, height: 669)
        } else if let text = value(after: "-previewSize") {
            let parts = text.split(separator: "x").compactMap { Double($0) }
            if parts.count == 2 { previewSize = CGSize(width: parts[0], height: parts[1]) }
        }
    }
}
