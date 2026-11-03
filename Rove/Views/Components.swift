import SwiftUI

/// A round initial badge for a person.
struct Avatar: View {
    let person: Person
    var size: CGFloat = 32
    var partySize: Int = 1

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Circle()
                .fill(Theme.color(for: person))
                .frame(width: size, height: size)
                .overlay(
                    Text(person.initials)
                        .font(.system(size: size * 0.38, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                )
            if partySize > 1 {
                Text("×\(partySize)")
                    .font(.system(size: max(9, size * 0.3), weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 3)
                    .background(Capsule().fill(Color.black.opacity(0.75)))
                    .offset(x: 4, y: 2)
            }
        }
        .accessibilityLabel(partySize > 1 ? "\(person.name), party of \(partySize)" : person.name)
    }
}

/// Overlapping avatars, "+3" past the limit.
struct AvatarStack: View {
    let people: [Person]
    var size: CGFloat = 28
    var limit: Int = 5

    var body: some View {
        // A small overlap with a ring in the card's colour, so every set of
        // initials stays readable.
        HStack(spacing: -size * 0.16) {
            ForEach(people.prefix(limit)) { person in
                Avatar(person: person, size: size)
                    .padding(2)
                    .background(Circle().fill(Theme.card))
            }
            if people.count > limit {
                Text("+\(people.count - limit)")
                    .font(.system(size: size * 0.38, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .frame(width: size, height: size)
                    .background(Circle().fill(Theme.inset))
                    .padding(2)
                    .background(Circle().fill(Theme.card))
            }
        }
    }
}

/// A short status, like "Interested" or "In 17 days": a coloured dot and
/// the word, no box around it.
struct Chip: View {
    let text: String
    var symbol: String? = nil
    var color: Color = .secondary

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(text).font(.caption.weight(.medium)).foregroundStyle(.secondary)
        }
        .lineLimit(1)
        .accessibilityElement(children: .combine)
    }
}

/// An SF Symbol on a quiet square, used for plan items and costs. The
/// colour is left out on purpose so lists stay calm.
struct IconTile: View {
    let symbol: String
    let color: Color
    var size: CGFloat = 36

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            .fill(Theme.inset)
            .frame(width: size, height: size)
            .overlay(Image(systemName: symbol).font(.system(size: size * 0.42, weight: .medium)).foregroundStyle(.secondary))
            // Always beside words that say the same thing.
            .accessibilityHidden(true)
    }
}

/// A section title above cards.
struct SectionHeader: View {
    let title: String
    var detail: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.headline)
            Spacer()
            if let detail {
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 4)
        .padding(.top, 8)
    }
}

/// A big number with a caption under it.
struct StatView: View {
    let value: String
    let caption: String
    var color: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.title2.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(caption).font(.caption).foregroundStyle(.secondary).lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A full-width tinted button.
struct WideButtonStyle: ButtonStyle {
    var prominent = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(prominent ? Theme.onAccent : Color.accentColor)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(prominent ? Color.accentColor : Color.accentColor.opacity(0.12))
            )
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

/// Side by side, or one under the other at the largest text sizes so
/// nothing gets cut off.
struct AdaptiveStack<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    var horizontalAlignment: HorizontalAlignment = .leading
    var verticalAlignment: VerticalAlignment = .center
    var spacing: CGFloat? = nil
    @ViewBuilder var content: Content

    var body: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: horizontalAlignment, spacing: spacing))
            : AnyLayout(HStackLayout(alignment: verticalAlignment, spacing: spacing))
        layout { content }
    }
}

/// A small rounded button, like "Add" or "View on Airbnb". It is drawn at
/// least 44 points tall, the size Apple asks for, so it's easy to hit.
struct PillButtonStyle: ButtonStyle {
    /// Grey instead of teal, for the quieter of two actions.
    var neutral = false
    var fullWidth = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .foregroundStyle(neutral ? Color.primary : Color.accentColor)
            .padding(.horizontal, 16)
            .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: 44)
            .background(Capsule().fill(neutral ? Theme.inset : Color.accentColor.opacity(0.15)))
            .contentShape(Capsule())
            .opacity(configuration.isPressed ? 0.6 : isEnabled ? 1 : 0.4)
    }
}

/// Text field for money in the smallest unit, showing the currency symbol.
struct MoneyField: View {
    let title: String
    @Binding var minor: Int64?
    let currency: String
    var identifier: String? = nil
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack {
            if !title.isEmpty {
                Text(title)
                Spacer(minLength: 12)
            }
            TextField(Money(0, currency).formatted(), text: $text)
                .keyboardType(Currencies.digits(currency) == 0 ? .numberPad : .decimalPad)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .focused($focused)
                .accessibilityIdentifier(identifier ?? title)
                .onChange(of: text) {
                    minor = MoneyParser.parse(text, currency: currency)
                }
        }
        .onAppear { text = minor.map { Money($0, currency).plainText } ?? "" }
        .onChange(of: minor) {
            // Follow changes made from outside (a receipt scan), not while typing.
            if !focused { text = minor.map { Money($0, currency).plainText } ?? "" }
        }
    }
}

/// A person row with an avatar.
struct PersonRow: View {
    let person: Person
    var title: String? = nil
    var subtitle: String? = nil
    var partySize: Int = 1

    var body: some View {
        HStack(spacing: 12) {
            Avatar(person: person, size: 34, partySize: partySize)
            VStack(alignment: .leading, spacing: 1) {
                Text(title ?? person.name).lineLimit(2)
                if let subtitle {
                    Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
            }
        }
    }
}
