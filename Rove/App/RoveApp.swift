import SwiftUI

@main
struct RoveApp: App {
    @State private var store = TripStore.make(options: .current)
    private let options = LaunchOptions.current

    var body: some Scene {
        WindowGroup {
            Group {
                if let size = options.previewSize {
                    ScreenPreview(screen: size) { RootView(inline: true) }
                } else {
                    RootView()
                }
            }
            .environment(store)
            // Rove is always dark.
            .preferredColorScheme(.dark)
        }
    }
}

/// The app's three places: Trips, Groups and You. On most iPhones they sit in
/// a tab bar at the bottom; on the iPhone Duo the system puts them in the
/// strip at the side of the screen. A trip opens over everything, with its
/// own Overview, Plan, Expenses and Balances tabs in the same place.
struct RootView: View {
    /// Draw an open trip in place instead of over the screen, for the drawn
    /// open Duo preview, whose frame a cover can't sit inside.
    var inline = false

    @Environment(TripStore.self) private var store
    @State private var section: AppSection
    @State private var openTrip: OpenTrip?
    @State private var tripTab: TripTab
    private let options = LaunchOptions.current

    init(inline: Bool = false) {
        self.inline = inline
        let options = LaunchOptions.current
        _section = State(initialValue: AppSection(rawValue: options.section ?? "") ?? .trips)
        _tripTab = State(initialValue: TripTab(rawValue: options.tab ?? "") ?? .overview)
    }

    var body: some View {
        Group {
            if inline, let openTrip {
                TripScreen(tripID: openTrip.id, tab: $tripTab, onClose: { self.openTrip = nil })
            } else {
                tabs
            }
        }
        .fullScreenCover(item: inline ? .constant(nil) : $openTrip) { trip in
            TripScreen(tripID: trip.id, tab: $tripTab, onClose: { openTrip = nil })
                .environment(store)
        }
        .environment(\.openTrip) { id in
            tripTab = .overview
            openTrip = OpenTrip(id: id)
        }
        .tint(Color.accentColor)
        .onAppear {
            if let name = options.openTrip, openTrip == nil,
               let trip = store.trips.first(where: { $0.name.lowercased().hasPrefix(name.lowercased()) }) {
                openTrip = OpenTrip(id: trip.id)
            }
        }
    }

    private var tabs: some View {
        TabView(selection: $section) {
            Tab("Trips", systemImage: "suitcase", value: AppSection.trips) {
                NavigationStack { TripsView() }
            }
            Tab("Groups", systemImage: "person.2", value: AppSection.groups) {
                GroupsView()
            }
            Tab("You", systemImage: "person.crop.circle", value: AppSection.you) {
                ProfileView()
            }
        }
    }
}

enum AppSection: String, Hashable {
    case trips, groups, you
}

struct OpenTrip: Identifiable, Hashable {
    let id: UUID
}

extension EnvironmentValues {
    /// Opens a trip over the whole screen.
    @Entry var openTrip: (UUID) -> Void = { _ in }
}

/// The app drawn at another phone's screen size, shrunk to fit whatever
/// simulator runs it. The automatic checks can't unfold the Duo simulator,
/// so they use this to show the open Duo (about 951 by 669 points).
/// Used only with -openDuoPreview or -previewSize.
struct ScreenPreview<Content: View>: View {
    let screen: CGSize
    @ViewBuilder var content: Content

    /// Wide and tall enough to count as regular both ways, like the open Duo.
    private var regular: Bool { screen.width >= 700 && screen.height >= 600 }

    var body: some View {
        GeometryReader { geometry in
            let scale = min(geometry.size.width / screen.width, geometry.size.height / screen.height)
            content
                .padding(.top, 8)
                .frame(width: screen.width, height: screen.height)
                // The open Duo is regular width and height, like the real one,
                // so the screens lay out as they will there.
                .modifier(RegularSizeClasses(isOn: regular))
                .background(Theme.background)
                .clipped()
                .scaleEffect(scale)
                .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .background(Color.black)
        .ignoresSafeArea()
    }
}

/// Regular width and height, as on the open Duo, for a drawn preview.
private struct RegularSizeClasses: ViewModifier {
    let isOn: Bool

    func body(content: Content) -> some View {
        if isOn {
            content
                .environment(\.horizontalSizeClass, .regular)
                .environment(\.verticalSizeClass, .regular)
        } else {
            content
        }
    }
}
