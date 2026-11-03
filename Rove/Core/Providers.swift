import Foundation

/// Recognizes where a pasted listing link points, to label its button
/// ("View on Expedia"). Unknown sites get a plain "Open listing".
enum ListingLinks {
    struct Provider: Hashable {
        let name: String
        let hosts: [String]
    }

    static let providers: [Provider] = [
        Provider(name: "Expedia", hosts: ["expedia.com", "expedia.co.uk", "expedia.ca", "expedia.mx"]),
        Provider(name: "Airbnb", hosts: ["airbnb.com", "airbnb.ca", "airbnb.co.uk", "airbnb.mx", "abnb.me"]),
        Provider(name: "Vrbo", hosts: ["vrbo.com"]),
        Provider(name: "Booking.com", hosts: ["booking.com"]),
        Provider(name: "Hotels.com", hosts: ["hotels.com"]),
        Provider(name: "Kayak", hosts: ["kayak.com"]),
        Provider(name: "Google Flights", hosts: ["google.com/travel/flights"]),
        Provider(name: "Google Maps", hosts: ["maps.google.com", "google.com/maps", "maps.app.goo.gl", "goo.gl/maps"]),
        Provider(name: "Apple Maps", hosts: ["maps.apple.com"]),
        Provider(name: "Tripadvisor", hosts: ["tripadvisor.com"]),
        Provider(name: "Yelp", hosts: ["yelp.com"]),
        Provider(name: "OpenTable", hosts: ["opentable.com"]),
        Provider(name: "Resy", hosts: ["resy.com"]),
        Provider(name: "Tock", hosts: ["exploretock.com"]),
        Provider(name: "Viator", hosts: ["viator.com"]),
        Provider(name: "GetYourGuide", hosts: ["getyourguide.com"]),
        Provider(name: "Ticketmaster", hosts: ["ticketmaster.com"]),
        Provider(name: "Marriott", hosts: ["marriott.com"]),
        Provider(name: "Hilton", hosts: ["hilton.com"]),
        Provider(name: "Hyatt", hosts: ["hyatt.com"]),
        Provider(name: "IHG", hosts: ["ihg.com"]),
        Provider(name: "Delta", hosts: ["delta.com"]),
        Provider(name: "American Airlines", hosts: ["aa.com"]),
        Provider(name: "United", hosts: ["united.com"]),
        Provider(name: "JetBlue", hosts: ["jetblue.com"]),
        Provider(name: "Southwest", hosts: ["southwest.com"]),
        Provider(name: "Spirit", hosts: ["spirit.com"]),
        Provider(name: "Hertz", hosts: ["hertz.com"]),
        Provider(name: "Turo", hosts: ["turo.com"]),
    ]

    /// The link as a URL, adding https:// when someone pasted "airbnb.com/...".
    static func url(_ text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains(" ") else { return nil }
        let withScheme = trimmed.lowercased().hasPrefix("http://") || trimmed.lowercased().hasPrefix("https://")
            ? trimmed : "https://\(trimmed)"
        guard let url = URL(string: withScheme), let host = url.host, host.contains(".") else { return nil }
        return url
    }

    static func provider(for text: String) -> Provider? {
        guard let url = url(text), var host = url.host?.lowercased() else { return nil }
        if host.hasPrefix("www.") { host.removeFirst(4) }
        let hostAndPath = host + url.path.lowercased()
        return providers.first { provider in
            provider.hosts.contains { pattern in
                if pattern.contains("/") { return hostAndPath.hasPrefix(pattern) || hostAndPath.contains("." + pattern) }
                return host == pattern || host.hasSuffix("." + pattern)
            }
        }
    }

    /// "View on Expedia", or "Open listing" for a site we don't know.
    static func buttonTitle(for text: String) -> String {
        if let provider = provider(for: text) { return "View on \(provider.name)" }
        return "Open listing"
    }

    /// A short label for the link itself: the site's name, else its host.
    static func shortLabel(for text: String) -> String {
        if let provider = provider(for: text) { return provider.name }
        guard let host = url(text)?.host?.lowercased() else { return text }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }
}

/// Apple Maps links for a place: they open the Maps app on iPhone.
enum MapsLinks {
    static func directions(to place: Place) -> URL? {
        var components = URLComponents(string: "https://maps.apple.com/")
        components?.queryItems = [
            URLQueryItem(name: "daddr", value: "\(place.latitude),\(place.longitude)"),
            URLQueryItem(name: "q", value: place.name),
        ]
        return components?.url
    }

    static func show(_ place: Place) -> URL? {
        var components = URLComponents(string: "https://maps.apple.com/")
        components?.queryItems = [
            URLQueryItem(name: "ll", value: "\(place.latitude),\(place.longitude)"),
            URLQueryItem(name: "q", value: place.name),
        ]
        return components?.url
    }
}
