import SwiftUI
import UIKit

/// Rove's look: system greys, white cards, one teal accent.
enum Theme {
    static let background = Color(uiColor: .systemGroupedBackground)
    static let card = Color(uiColor: .secondarySystemGroupedBackground)
    static let inset = Color(uiColor: .tertiarySystemGroupedBackground)
    static let accent = Color.accentColor
    static let positive = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(red: 0.35, green: 0.82, blue: 0.55, alpha: 1)
        : UIColor(red: 0.10, green: 0.56, blue: 0.30, alpha: 1) })
    static let negative = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(red: 1.00, green: 0.50, blue: 0.45, alpha: 1)
        : UIColor(red: 0.80, green: 0.20, blue: 0.16, alpha: 1) })
    static let warning = Color.orange

    static let avatarColors: [Color] = [
        Color(red: 0.11, green: 0.55, blue: 0.50),
        Color(red: 0.85, green: 0.38, blue: 0.33),
        Color(red: 0.33, green: 0.42, blue: 0.80),
        Color(red: 0.80, green: 0.55, blue: 0.13),
        Color(red: 0.55, green: 0.36, blue: 0.75),
        Color(red: 0.22, green: 0.60, blue: 0.82),
        Color(red: 0.45, green: 0.58, blue: 0.25),
        Color(red: 0.55, green: 0.55, blue: 0.58),
    ]

    static func color(for person: Person) -> Color {
        avatarColors[abs(person.colorIndex) % avatarColors.count]
    }

    static func color(for response: Response?) -> Color {
        switch response {
        case .interested: return positive
        case .maybe: return .orange
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

extension View {
    /// A white rounded card on the grey background.
    func card(padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

