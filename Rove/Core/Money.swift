import Foundation

/// Currencies the app knows how to show. Amounts are always whole numbers of
/// the currency's smallest unit (cents for dollars, yen for yen), never
/// floating point.
enum Currencies {
    struct Info: Hashable {
        let code: String
        let name: String
        let digits: Int
    }

    static let all: [Info] = [
        Info(code: "USD", name: "US Dollar", digits: 2),
        Info(code: "EUR", name: "Euro", digits: 2),
        Info(code: "GBP", name: "British Pound", digits: 2),
        Info(code: "CAD", name: "Canadian Dollar", digits: 2),
        Info(code: "MXN", name: "Mexican Peso", digits: 2),
        Info(code: "DOP", name: "Dominican Peso", digits: 2),
        Info(code: "CRC", name: "Costa Rican Colón", digits: 2),
        Info(code: "COP", name: "Colombian Peso", digits: 2),
        Info(code: "BRL", name: "Brazilian Real", digits: 2),
        Info(code: "JPY", name: "Japanese Yen", digits: 0),
        Info(code: "KRW", name: "South Korean Won", digits: 0),
        Info(code: "AUD", name: "Australian Dollar", digits: 2),
        Info(code: "CHF", name: "Swiss Franc", digits: 2),
    ]

    static var codes: [String] { all.map(\.code) }

    static func digits(_ code: String) -> Int {
        all.first { $0.code == code }?.digits ?? 2
    }

    static func name(_ code: String) -> String {
        all.first { $0.code == code }?.name ?? code
    }

    /// 10 to the power of the currency's digits: 100 for dollars, 1 for yen.
    static func scale(_ code: String) -> Int64 {
        var value: Int64 = 1
        for _ in 0..<digits(code) { value *= 10 }
        return value
    }
}

/// An amount of money in one currency, in its smallest unit.
struct Money: Hashable, Codable, Comparable {
    var minor: Int64
    var currency: String

    init(_ minor: Int64, _ currency: String) {
        self.minor = minor
        self.currency = currency
    }

    static func zero(_ currency: String) -> Money { Money(0, currency) }

    static func < (lhs: Money, rhs: Money) -> Bool { lhs.minor < rhs.minor }

    static func + (lhs: Money, rhs: Money) -> Money { Money(lhs.minor + rhs.minor, lhs.currency) }
    static func - (lhs: Money, rhs: Money) -> Money { Money(lhs.minor - rhs.minor, lhs.currency) }

    var isZero: Bool { minor == 0 }

    /// Exact decimal value, e.g. 1234 cents -> 12.34. Only for display.
    var decimal: Decimal {
        Decimal(minor) / Decimal(Currencies.scale(currency))
    }

    /// "$1,234.56". With `wholeIfRound`, "$1,200" instead of "$1,200.00".
    func formatted(wholeIfRound: Bool = false) -> String {
        MoneyFormat.string(self, wholeIfRound: wholeIfRound)
    }

    /// Rounded to the nearest whole unit, "$1,359" for $1,359.29. Estimates
    /// are rough, so cents only get in the way there.
    var rounded: String {
        let scale = Currencies.scale(currency)
        let half = scale / 2
        let whole = minor >= 0 ? (minor + half) / scale : -((-minor + half) / scale)
        return Money(whole * scale, currency).formatted(wholeIfRound: true)
    }

    /// "1234.56" for an editable text field.
    var plainText: String {
        let digits = Currencies.digits(currency)
        let sign = minor < 0 ? "-" : ""
        let value = minor.magnitude
        let scale = UInt64(Currencies.scale(currency))
        if digits == 0 { return "\(sign)\(value)" }
        let whole = value / scale
        let fraction = value % scale
        let fractionText = String(fraction)
        let padded = String(repeating: "0", count: digits - fractionText.count) + fractionText
        return "\(sign)\(whole).\(padded)"
    }
}

enum MoneyFormat {
    private static var cache: [String: NumberFormatter] = [:]
    private static let lock = NSLock()

    static func string(_ money: Money, wholeIfRound: Bool) -> String {
        let digits = Currencies.digits(money.currency)
        let round = money.minor % Currencies.scale(money.currency) == 0
        let shownDigits = (wholeIfRound && round) ? 0 : digits
        let key = "\(money.currency)-\(shownDigits)"
        lock.lock()
        let formatter: NumberFormatter
        if let cached = cache[key] {
            formatter = cached
        } else {
            formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.locale = Locale(identifier: "en_US")
            formatter.currencyCode = money.currency
            formatter.minimumFractionDigits = shownDigits
            formatter.maximumFractionDigits = shownDigits
            cache[key] = formatter
        }
        let text = formatter.string(from: money.decimal as NSDecimalNumber)
        lock.unlock()
        return text ?? "\(money.currency) \(money.plainText)"
    }
}

/// Turns what someone typed ("12.5", "$1,234.56", "1200") into the smallest
/// unit, without going through floating point. Nil when it isn't an amount.
enum MoneyParser {
    static func parse(_ text: String, currency: String) -> Int64? {
        let digits = Currencies.digits(currency)
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        var negative = false
        if cleaned.hasPrefix("-") {
            negative = true
            cleaned.removeFirst()
        }
        cleaned = String(cleaned.filter { $0.isNumber || $0 == "." || $0 == "," })
        cleaned = cleaned.replacingOccurrences(of: ",", with: "")
        guard !cleaned.isEmpty else { return nil }
        let parts = cleaned.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count <= 2 else { return nil }
        let wholeText = parts[0].isEmpty ? "0" : String(parts[0])
        guard wholeText.allSatisfy(\.isNumber), let whole = Int64(wholeText) else { return nil }
        var fraction: Int64 = 0
        if parts.count == 2 {
            let fractionText = String(parts[1])
            guard fractionText.allSatisfy(\.isNumber), fractionText.count <= digits else { return nil }
            let padded = fractionText + String(repeating: "0", count: digits - fractionText.count)
            fraction = padded.isEmpty ? 0 : (Int64(padded) ?? 0)
        }
        let (scaled, overflow) = whole.multipliedReportingOverflow(by: Currencies.scale(currency))
        guard !overflow else { return nil }
        let value = scaled + fraction
        return negative ? -value : value
    }
}

/// Converting an expense to the trip's currency. The rate is "1 unit of the
/// expense currency = rate units of the trip currency", the way a bank shows
/// it. The result is rounded half up to the trip currency's smallest unit.
enum Conversion {
    static func convert(_ minor: Int64, from: String, to: String, rate: Decimal) -> Int64 {
        if from == to { return minor }
        // amount in major units of `from`, times rate, in minor units of `to`
        var value = Decimal(minor) * rate * Decimal(Currencies.scale(to)) / Decimal(Currencies.scale(from))
        var rounded = Decimal()
        NSDecimalRound(&rounded, &value, 0, .plain)
        return NSDecimalNumber(decimal: rounded).int64Value
    }

    /// "1.08" -> 1.08, accepting a comma too. Nil when it isn't a positive number.
    static func parseRate(_ text: String) -> Decimal? {
        let cleaned = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        guard !cleaned.isEmpty,
              cleaned.allSatisfy({ $0.isNumber || $0 == "." }),
              cleaned.filter({ $0 == "." }).count <= 1,
              let value = Decimal(string: cleaned, locale: Locale(identifier: "en_US_POSIX")),
              value > 0 else { return nil }
        return value
    }

    /// A starting rate for common currencies so a new expense isn't blank.
    /// Always shown to the person to check against their card or bank.
    static func sampleRate(from: String, to: String) -> Decimal? {
        // Rough US dollars per unit, only a starting point.
        let usdPer: [String: String] = [
            "USD": "1", "EUR": "1.08", "GBP": "1.27", "CAD": "0.73", "MXN": "0.055",
            "DOP": "0.017", "CRC": "0.0019", "COP": "0.00025", "BRL": "0.18",
            "JPY": "0.0067", "KRW": "0.00073", "AUD": "0.66", "CHF": "1.13",
        ]
        guard let a = usdPer[from].flatMap({ Decimal(string: $0, locale: Locale(identifier: "en_US_POSIX")) }),
              let b = usdPer[to].flatMap({ Decimal(string: $0, locale: Locale(identifier: "en_US_POSIX")) }),
              b > 0 else { return nil }
        var value = a / b
        var rounded = Decimal()
        NSDecimalRound(&rounded, &value, 6, .plain)
        return rounded
    }

    static func rateText(_ rate: Decimal) -> String {
        NSDecimalNumber(decimal: rate).stringValue
    }
}
