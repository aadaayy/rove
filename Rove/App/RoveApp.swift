import SwiftUI

@main
struct RoveApp: App {
    @State private var store = TripStore.make(options: .current)
    private let options = LaunchOptions.current

    var body: some Scene {
        WindowGroup {
            Group {
                if let size = options.previewSize {
                    ScreenPreview(screen: size) { RootView() }
                } else {
                    RootView()
                }
            }
            .environment(store)
            .preferredColorScheme(options.dark ? .dark : nil)
        }
    }
}

/// The trips list, with everything else pushed on top of it.
struct RootView: View {
    @Environment(TripStore.self) private var store
    @State private var path: [UUID] = []
    private let options = LaunchOptions.current

    var body: some View {
        NavigationStack(path: $path) {
            TripsView()
                .navigationDestination(for: UUID.self) { id in
                    TripDetailView(tripID: id, initialTab: TripTab(rawValue: options.tab ?? "") ?? .overview)
                }
        }
        .tint(Color.accentColor)
        .onAppear {
            if let name = options.openTrip, path.isEmpty,
               let trip = store.trips.first(where: { $0.name.lowercased().hasPrefix(name.lowercased()) }) {
                path = [trip.id]
            }
        }
    }
}

/// The app drawn at another phone's screen size, shrunk to fit whatever
/// simulator runs it. The automatic checks can't unfold the Duo simulator,
/// so they use this to show the open Duo (about 951 by 669 points).
/// Used only with -openDuoPreview or -previewSize.
struct ScreenPreview<Content: View>: View {
    let screen: CGSize
    @ViewBuilder var content: Content

    var body: some View {
        GeometryReader { geometry in
            let scale = min(geometry.size.width / screen.width, geometry.size.height / screen.height)
            content
                .padding(.top, 8)
                .frame(width: screen.width, height: screen.height)
                .clipped()
                .scaleEffect(scale)
                .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .background(Color.black)
        .ignoresSafeArea()
    }
}
