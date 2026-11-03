import XCTest

/// Walks through every main screen on each simulator, using the app the way
/// a person would, and saves a screenshot of each. Every launch starts from
/// the same sample trips, so the pictures are comparable run to run.
final class WalkthroughUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    private static var device: String { ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] ?? "" }

    // MARK: - Home and ideas

    @MainActor
    func test1HomeAndIdeas() throws {
        let app = launch()
        XCTAssertTrue(app.buttons["trip-Nashville Long Weekend"].waitForExistence(timeout: 20), "The trips list didn't appear")
        XCTAssertTrue(app.buttons["trip-Cancún Spring Break"].exists)
        capture("01-trips")

        // An idea: answer it and sign up for two.
        open(app, "trip-Cancún Spring Break")
        XCTAssertTrue(app.buttons["respond-interested"].waitForExistence(timeout: 5))
        capture("02-idea-not-answered")
        app.buttons["respond-interested"].tap()
        let stepper = app.steppers["party-size"]
        XCTAssertTrue(stepper.waitForExistence(timeout: 3), "Answering should show the party size")
        stepper.buttons.element(boundBy: 1).tap()
        XCTAssertTrue(app.staticTexts["Me + 1"].waitForExistence(timeout: 3), "Party of 2 should read Me + 1")
        capture("03-idea-answered-for-2")
        app.swipeUp()
        sleep(1)
        capture("04-idea-whos-in")
        XCTAssertTrue(app.buttons["make-it-a-trip"].exists, "Anyone can turn an idea into a trip")
        closeTrip(app)

        // A new idea.
        app.buttons["new-trip"].tap()
        let destination = app.textFields["destination"]
        XCTAssertTrue(destination.waitForExistence(timeout: 5))
        destination.tap()
        destination.typeText("Lisbon, Portugal\n")
        capture("05-new-idea")
        app.swipeUp()
        sleep(1)
        capture("06-new-idea-budget")
        tapBarButton(app, "save-proposal")
        XCTAssertTrue(app.buttons["trip-Lisbon trip"].waitForExistence(timeout: 5), "The new idea should be in the list")
    }

    // MARK: - A trip being planned

    @MainActor
    func test2TripOverviewAndPlan() throws {
        let app = launch()
        open(app, "trip-Nashville Long Weekend")
        XCTAssertTrue(app.buttons["close-trip"].waitForExistence(timeout: 5))
        capture("07-trip-overview")
        app.swipeUp()
        sleep(1)
        capture("08-trip-overview-estimate")

        tab(app, "Plan")
        XCTAssertTrue(app.buttons["add-place"].waitForExistence(timeout: 5))
        sleep(2) // map tiles
        capture("09-plan")
        XCTAssertTrue(app.buttons["View on Airbnb"].exists, "The Airbnb link should be labelled")
        app.swipeUp()
        sleep(1)
        capture("10-plan-days")
        let approve = app.buttons["approve-poll"]
        for _ in 0..<4 where !approve.isHittable { app.swipeUp() }
        XCTAssertTrue(approve.exists, "The organizer should see the poll waiting for approval")
        capture("11-polls")
        approve.tap()
        XCTAssertFalse(approve.waitForExistence(timeout: 2), "Approving should publish the poll")
        let vote = app.buttons["vote-Husk"]
        if vote.exists && vote.isHittable { vote.tap() }

        // Add to the plan.
        app.buttons["add-place"].firstMatch.tap()
        let title = app.textFields["place-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap()
        title.typeText("Johnny Cash Museum")
        let link = app.textFields["place-link"]
        link.tap()
        link.typeText("https://www.expedia.com/things-to-do/johnny-cash-museum")
        XCTAssertTrue(app.staticTexts["Shows as \u{201C}View on Expedia\u{201D}"].waitForExistence(timeout: 3))
        capture("12-add-to-plan")
        tapBarButton(app, "Cancel")

        // A new poll.
        let newPoll = app.buttons["new-poll"]
        for _ in 0..<4 where !newPoll.isHittable { app.swipeUp() }
        newPoll.tap()
        let question = app.textFields["poll-question"]
        XCTAssertTrue(question.waitForExistence(timeout: 5))
        question.tap()
        question.typeText("Sunday brunch spot?")
        app.textFields["poll-option-1"].tap()
        app.textFields["poll-option-1"].typeText("Pancake Pantry")
        app.textFields["poll-option-2"].tap()
        app.textFields["poll-option-2"].typeText("Biscuit Love")
        capture("13-new-poll")
        tapBarButton(app, "post-poll")
        XCTAssertTrue(app.staticTexts["Sunday brunch spot?"].waitForExistence(timeout: 5), "The new poll should show")
    }

    // MARK: - Money

    @MainActor
    func test3ExpensesAndBalances() throws {
        let app = launch()
        open(app, "trip-Nashville Long Weekend")
        tab(app, "Expenses")
        XCTAssertTrue(app.buttons["add-expense"].waitForExistence(timeout: 5))
        capture("14-expenses")

        app.buttons["add-expense"].tap()
        let title = app.textFields["expense-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap()
        title.typeText("Taxi from BNA")
        let amount = app.textFields["expense-amount"]
        amount.tap()
        amount.typeText("48.60")
        capture("15-new-expense")
        app.swipeUp()
        sleep(1)
        capture("16-new-expense-split")
        tapBarButton(app, "save-expense")
        XCTAssertTrue(app.buttons["expense-Taxi from BNA"].waitForExistence(timeout: 5), "The new expense should be listed")

        // A custom split on an existing expense, once the last form has gone.
        _ = app.textFields["expense-title"].waitForNonExistence(timeout: 5)
        app.buttons["expense-Birthday cake for Maria"].tap()
        XCTAssertTrue(app.textFields["expense-title"].waitForExistence(timeout: 5))
        app.swipeUp()
        sleep(1)
        capture("17-custom-split")
        tapBarButton(app, "Cancel")

        tab(app, "Balances")
        XCTAssertTrue(app.staticTexts["Suggested repayments"].waitForExistence(timeout: 5))
        capture("18-balances")
        let markPaid = app.buttons["mark-paid-Jordan-Alberto"]
        XCTAssertTrue(markPaid.exists, "Jordan should owe Alberto")
        if !markPaid.isHittable { app.swipeUp() }
        markPaid.tap()
        let confirm = app.buttons["confirm-paid"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "Marking as paid should ask first")
        confirm.tap()
        XCTAssertTrue(markPaid.waitForNonExistence(timeout: 5), "Paid repayments drop off the list")
        app.swipeUp()
        sleep(1)
        capture("19-balances-after-paying")
    }

    // MARK: - Settings, groups, you

    @MainActor
    func test4SettingsGroupsProfile() throws {
        let app = launch()
        open(app, "trip-Nashville Long Weekend")
        app.buttons["trip-settings"].tap()
        XCTAssertTrue(app.buttons["save-settings"].waitForExistence(timeout: 5))
        capture("20-trip-settings")
        for _ in 0..<3 { app.swipeUp() }
        sleep(1)
        capture("21-trip-settings-polls")
        tapBarButton(app, "Cancel")
        closeTrip(app)

        tab(app, "Groups")
        XCTAssertTrue(app.navigationBars["Groups"].waitForExistence(timeout: 5))
        capture("22-groups")

        tab(app, "You")
        XCTAssertTrue(app.navigationBars["You"].waitForExistence(timeout: 5))
        capture("23-profile")
    }

    // MARK: - Open iPhone Duo

    /// The open iPhone Duo drawn at its real size and shrunk to fit a
    /// sideways Pro Max, since the Duo simulator can't be unfolded here.
    @MainActor
    func test6OpenDuo() throws {
        try XCTSkipUnless(Self.device.contains("Pro Max"), "These pictures are taken on the Pro Max only")
        XCUIDevice.shared.orientation = .landscapeLeft
        var app = launch(["-openDuoPreview"])
        XCTAssertTrue(app.buttons["trip-Nashville Long Weekend"].waitForExistence(timeout: 20))
        sleep(1)
        capture("30-open-duo-trips")
        let shots: [(String, String, String)] = [
            ("Cancún", "overview", "31-open-duo-idea"),
            ("Nashville", "overview", "32-open-duo-overview"),
            ("Nashville", "plan", "33-open-duo-plan"),
            ("Nashville", "expenses", "34-open-duo-expenses"),
            ("Nashville", "balances", "35-open-duo-balances"),
        ]
        for (trip, part, name) in shots {
            app = launch(["-openDuoPreview", "-openTrip", trip, "-tab", part])
            XCTAssertTrue(app.buttons["close-trip"].waitForExistence(timeout: 20))
            sleep(part == "plan" ? 3 : 1)
            capture(name)
        }
        for (section, name) in [("groups", "36-open-duo-groups"), ("you", "38-open-duo-profile")] {
            app = launch(["-openDuoPreview", "-section", section])
            sleep(2)
            capture(name)
        }
    }

    /// The Pro Max on its side uses the same wide layouts.
    @MainActor
    func test7Sideways() throws {
        try XCTSkipUnless(Self.device.contains("Pro Max"), "Taken on the Pro Max only")
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = launch(["-openTrip", "Nashville", "-tab", "plan"])
        XCTAssertTrue(app.buttons["close-trip"].waitForExistence(timeout: 20))
        sleep(3)
        capture("37-sideways-plan")
    }

    // MARK: - Largest text

    /// The biggest accessibility text size, on the narrowest screen (the
    /// folded Duo) and a regular one, to check nothing is cut off or overlaps.
    @MainActor
    func test8LargestText() throws {
        try XCTSkipUnless(Self.device.contains("Duo") || Self.device.hasSuffix("18 Pro"), "Taken on the Duo and the Pro")
        let big = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"]
        var app = launch(big)
        XCTAssertTrue(app.buttons["trip-Nashville Long Weekend"].waitForExistence(timeout: 20))
        capture("40-large-text-trips")
        let shots: [(String, String, String)] = [
            ("Cancún", "overview", "41-large-text-idea"),
            ("Nashville", "overview", "42-large-text-overview"),
            ("Nashville", "plan", "43-large-text-plan"),
            ("Nashville", "expenses", "44-large-text-expenses"),
            ("Nashville", "balances", "45-large-text-balances"),
        ]
        for (trip, part, name) in shots {
            app = launch(big + ["-openTrip", trip, "-tab", part])
            XCTAssertTrue(app.buttons["close-trip"].waitForExistence(timeout: 20))
            sleep(part == "plan" ? 3 : 1)
            capture(name)
        }
    }

    /// A Pro screen drawn the same way as the open Duo, to tell what is the
    /// drawing and what is the app: compare it with the Pro's own 01-trips.
    @MainActor
    func test9DrawnCheck() throws {
        try XCTSkipUnless(Self.device.contains("Pro Max"), "Taken on the Pro Max only")
        let app = launch(["-previewSize", "402x874"])
        XCTAssertTrue(app.buttons["trip-Nashville Long Weekend"].waitForExistence(timeout: 20))
        sleep(1)
        capture("39-drawn-pro-check")
    }

    // MARK: - Helpers

    @MainActor
    private func launch(_ arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"] + arguments
        app.launch()
        return app
    }

    @MainActor
    private func open(_ app: XCUIApplication, _ identifier: String) {
        let card = app.buttons[identifier]
        XCTAssertTrue(card.waitForExistence(timeout: 20), "\(identifier) is missing")
        for _ in 0..<4 where !card.isHittable { app.swipeUp() }
        card.tap()
    }

    /// Back from a trip to the list. The button sits in the top bar on most
    /// iPhones and in the side strip on the Duo.
    @MainActor
    private func closeTrip(_ app: XCUIApplication) {
        let close = app.buttons["close-trip"].firstMatch
        XCTAssertTrue(close.waitForExistence(timeout: 5), "Back to trips is missing")
        close.tap()
        XCTAssertTrue(app.buttons["new-trip"].waitForExistence(timeout: 5), "The trips list should be back")
    }

    /// Taps a button in a sheet's top bar. On the folded Duo the bar slides
    /// away as the form scrolls, so scroll back up first.
    @MainActor
    private func tapBarButton(_ app: XCUIApplication, _ identifier: String) {
        let button = app.buttons[identifier]
        for _ in 0..<6 where !(button.exists && button.isHittable) {
            app.swipeDown(velocity: .slow)
        }
        XCTAssertTrue(button.waitForExistence(timeout: 3), "\(identifier) is missing")
        button.tap()
    }

    @MainActor
    /// Tabs sit in a tab bar on most iPhones and in the side strip on the Duo.
    private func tab(_ app: XCUIApplication, _ title: String) {
        let inBar = app.tabBars.buttons[title]
        let button = inBar.waitForExistence(timeout: 3) ? inBar : app.buttons[title].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 5), "No \(title) tab")
        button.tap()
        sleep(1)
    }

    @MainActor
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
