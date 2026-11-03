import SwiftUI
import UIKit

/// Rove's look: always dark, quiet greys, one teal accent. Colour is kept
/// for what it means (owed, paid, your answer), not for decoration.
enum Theme {
    static let background = Color(uiColor: .systemGroupedBackground)
    static let card = Color(uiColor: .secondarySystemGroupedBackground)
    static let inset = Color(uiColor: .tertiarySystemGroupedBackground)
    static let accent = Color.accentColor
    static let positive = Color(red: 0.35, green: 0.82, blue: 0.55)
    static let negative = Color(red: 1.00, green: 0.50, blue: 0.45)
    static let warning = Color(red: 1.00, green: 0.70, blue: 0.30)
    /// Text on the teal accent. The accent is light in the dark, so white on
    /// it is too faint to read (2:1); black is 10:1.
    static let onAccent = Color.black

    /// Deep enough that white initials read at 4.5:1 or better on every one.
    static let avatarColors: [Color] = [
        Color(red: 0.10, green: 0.51, blue: 0.46),
        Color(red: 0.74, green: 0.33, blue: 0.29),
        Color(red: 0.33, green: 0.42, blue: 0.80),
        Color(red: 0.61, green: 0.42, blue: 0.10),
        Color(red: 0.55, green: 0.36, blue: 0.75),
        Color(red: 0.18, green: 0.48, blue: 0.66),
        Color(red: 0.38, green: 0.49, blue: 0.21),
        Color(red: 0.46, green: 0.46, blue: 0.48),
    ]

    static func color(for person: Person) -> Color {
        avatarColors[abs(person.colorIndex) % avatarColors.count]
    }

    static func color(for response: Response?) -> Color {
        switch response {
        case .interested: return positive
        case .maybe: return warning
        case .cantMakeIt: return .secondary
        case nil: return .secondary
        }
    }

    static func color(for kind: PlaceKind) -> Color {
        switch kind {
        case .stay: return Color(red: 0.33, green: 0.42, blue: 0.80)
        case .food: return Color(red: 0.85, green: 0.38, blue: 0.33)
        case .activity: return Color(red: 0.55, green: 0.36, blue: 0.75)
        case .flight: return Color(red: 0.22, green: 0.60, blue: 0.82)
        case .transport: return Color(red: 0.80, green: 0.55, blue: 0.13)
        case .other: return Color(red: 0.11, green: 0.55, blue: 0.50)
        }
    }

    static func color(for kind: CostKind) -> Color {
        switch kind {
        case .stay: return color(for: PlaceKind.stay)
        case .flights: return color(for: PlaceKind.flight)
        case .food: return color(for: PlaceKind.food)
        case .activities: return color(for: PlaceKind.activity)
        case .transport: return color(for: PlaceKind.transport)
        case .other: return color(for: PlaceKind.other)
        }
    }

    /// Width at which screens go side by side (the open iPhone Duo, phones on their side).
    static let wideWidth: CGFloat = 700
}

enum Formats {
    static func dateRange(_ start: Date, _ end: Date) -> String {
        let calendar = Calendar.current
        let sameYear = calendar.component(.year, from: start) == calendar.component(.year, from: end)
        let thisYear = calendar.component(.year, from: start) == calendar.component(.year, from: Date())
        if calendar.isDate(start, inSameDayAs: end) {
            return start.formatted(.dateTime.month(.abbreviated).day().year())
        }
        let startText = start.formatted(.dateTime.month(.abbreviated).day())
        let sameMonth = sameYear && calendar.component(.month, from: start) == calendar.component(.month, from: end)
        let endText = sameMonth ? end.formatted(.dateTime.day()) : end.formatted(.dateTime.month(.abbreviated).day())
        let year = (sameYear && thisYear) ? "" : ", \(end.formatted(.dateTime.year()))"
        return "\(startText) – \(endText)\(year)"
    }

    static func day(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    static func shortDay(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).day())
    }

    static func time(_ date: Date) -> String {
        date.formatted(.dateTime.hour().minute())
    }

    /// "in 17 days", "tomorrow", "now", "2 months ago".
    static func countdown(to start: Date, end: Date, today: Date = Date()) -> String {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: today), to: calendar.startOfDay(for: start)).day ?? 0
        let endDays = calendar.dateComponents([.day], from: calendar.startOfDay(for: today), to: calendar.startOfDay(for: end)).day ?? 0
        if days > 1 { return "In \(days) days" }
        if days == 1 { return "Tomorrow" }
        if endDays >= 0 { return "Happening now" }
        let ago = -endDays
        if ago < 14 { return "\(ago) day\(ago == 1 ? "" : "s") ago" }
        if ago < 60 { return "\(ago / 7) weeks ago" }
        return "\(ago / 30) months ago"
    }
}

/// Animates a change, unless the person has asked their iPhone for less motion.
@MainActor
func withMotion(_ change: () -> Void) {
    if UIAccessibility.isReduceMotionEnabled {
        change()
    } else {
        withAnimation(.default, change)
    }
}

/// The default animation, or none when Reduce Motion is on.
@MainActor
var gentleAnimation: Animation? { UIAccessibility.isReduceMotionEnabled ? nil : .default }

extension View {
    /// Keeps lists and forms to a comfortable reading width on wide screens,
    /// like the open iPhone Duo, instead of running edge to edge.
    func readableWidth(_ maxWidth: CGFloat = 640) -> some View {
        modifier(ReadableWidth(maxWidth: maxWidth))
    }

    /// A rounded card a shade lighter than the background.
    func card(padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}


private struct ReadableWidth: ViewModifier {
    let maxWidth: CGFloat
    @State private var width: CGFloat = 0

    func body(content: Content) -> some View {
        // Only on wide screens: on a phone the list keeps its own margins.
        Group {
            if width > maxWidth + 80 {
                content.contentMargins(.horizontal, (width - maxWidth) / 2, for: .scrollContent)
            } else {
                content
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
    }
}
