# Rove

Plan trips with friends and split what you spend. One shared trip takes a group from "should we go?" to "here's the plan" to "here's who owes who".

This first version runs entirely on the phone with sample trips and people, so every screen can be tried before any server exists. Nothing is sent anywhere.

## What's in it

1. Trips: upcoming trips, ideas people are answering, and past trips. Open-Duo and sideways layouts show two columns.
2. Ideas (proposals): where, when, a rough budget and who to ask. Budget lines can be per person, per day, per meal (like $50 a meal, 3 meals a day), a shared total, or shared per night. The estimate shows per person, for your party, and for the whole group.
3. Answers: Interested, Maybe or Can't make it. Anyone coming with someone who isn't on Rove sets their party to 2, and they count twice in estimates and equal splits.
4. Make it a trip: anyone on an idea can turn it into a trip with one button.
5. Plan: a map of every saved place, the itinerary by day, and place cards with the pasted link ("View on Airbnb", "View on Expedia", or "Open listing" for sites it doesn't know) and Open in Apple Maps. On the open Duo the map and itinerary sit side by side.
6. Polls: vote on dinner or anything else, tied to a plan item or a time slot. The organizer picks who can post: everyone, only people they pick, or anyone with the organizer approving first.
7. Expenses: what it was, amount, currency (with the rate you paid, saved with the expense), date, category, who paid, and who shares it. Equal split by default (by head, so a party of 2 pays two shares), or custom amounts.
8. Scan a receipt: pick a photo or screenshot; the phone reads it on the device, suggests the merchant, date, subtotal, tax, tip and total, and lets you check them. The picture is never kept.
9. Balances: what each person paid and owes, and the fewest repayments that settle everyone. Pay however you like (Venmo, Zelle, cash) and mark it paid.
10. Trip settings: basics, budget, people and party sizes, who can post polls, delete.
11. Groups: people join on their own, then invite each other into groups. Until accounts exist, inviting someone adds them right away.
12. You: your name, plus a Testing section to use the app as someone else (to answer, vote or approve as them) and to start over with the sample trips.

Later: Supabase accounts and sync, splitting a receipt item by item, push notifications, automatic exchange rates.

## How the code is laid out

1. `Rove/Core`: money (whole cents, never floating point), the trip model, estimates, splits, balances and repayments, link labels, the receipt reader's text parsing, and the sample data. Plain Swift, no screens, so it's tested on a cheap Linux machine with `swift test`.
2. `Rove/App`: the app's start, the store that saves to a file on the phone (`TripStore`, behind a `TripRepository` so Supabase can replace the file later), and the on-device receipt text recognition.
3. `Rove/Views`: the SwiftUI screens.
4. `Tests/RoveCoreTests`: the logic tests, with hand-worked examples (including a party of 2) written out in the comments.
5. `RoveUITests`: the walk-through that uses the app on the simulators and takes the screenshots.

## Checks and screenshots

Every push runs the logic tests, then builds the app and walks through every main screen on iPhone Pro Max, iPhone Pro and iPhone Duo simulators, in light and dark. The open Duo is drawn at its real size on the Pro Max. Screenshots land on the `screenshots` branch (from main) or `screenshots-<branch>` (from a working branch).

## Run it on your iPhone (free Apple account)

You need a Mac with Xcode 27.1 or later. No simulator is needed.

### First time

1. In Xcode, choose Integrate > Clone, paste `https://github.com/aadaayy/rove`, and pick a folder.
2. Open `Rove.xcodeproj` if it doesn't open by itself.
3. Xcode Settings > Accounts: sign in with your Apple account. A free account works; Xcode calls it a Personal Team.
4. Click the blue Rove project at the top of the file list, open Signing & Capabilities, and pick your Personal Team for the Rove target.
5. If Xcode says the bundle identifier is taken, change `com.albertoaday.rove` to something unique to you.
6. Plug the phone into the Mac with a cable and tap Trust on the phone. Developer Mode must be on (Settings > Privacy & Security > Developer Mode).
7. In Xcode, pick the phone from the device menu at the top and press Run (the play button).
8. The first time, the phone may block the app. Open Settings > General > VPN & Device Management, trust your developer certificate, and open the app again.

### Each time there's a new version

1. Integrate > Pull.
2. Press Run.

With a free account, apps installed this way stop opening after 7 days; press Run again to renew. A free account can have 3 such apps on a phone at once.

### Trying it as someone else

Tap your initials (top left), then under Testing pick another person in "Use Rove as". You'll see each trip the way they do: answer for them, vote, or approve polls as the organizer. "Start over with the sample trips" puts everything back.
