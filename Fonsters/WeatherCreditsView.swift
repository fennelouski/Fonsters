#if os(macOS) || os(iOS) || os(tvOS) || os(visionOS)
import SwiftUI

/// Supply Apple's actual downloaded marks. This view never starts a network
/// request in protected play. A weather display must have both marks available
/// before showing Apple data, rather than substitute an invented logo.
struct WeatherCreditsView: View {
    let lightMark: Image
    let darkMark: Image
    let legalPageURL: URL
    var transformed = false
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            (colorScheme == .dark ? darkMark : lightMark)
                .resizable().scaledToFit().frame(width: 104, height: 24, alignment: .leading)
                .accessibilityLabel("Apple Weather")
            WeatherSourceLink(title: "Weather data sources", url: legalPageURL).font(.caption)
            if transformed {
                Text("Weather scenery uses modified data from Apple Weather.")
                    .font(.caption).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10).background(.background, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityIdentifier("weatherCredits")
    }
}

struct WeatherInformationView: View {
    var body: some View {
        List {
            Section {
                Label("World weather", systemImage: "cloud.sun.fill").font(.headline)
                Text("Live shared weather is not connected in this preview. The world is a play environment, not a forecast.")
            }
            Section("Apple Weather") {
                Text("When live weather is available, Apple Weather supplies the conditions. Weather-driven scenery modifies those conditions for play.")
                WeatherSourceLink(title: "Apple Weather data sources", url: URL(string: "https://developer.apple.com/weatherkit/data-source-attribution/")!)
                Text("Weather credits also appear alongside live weather, so you can see its source without opening this menu.").font(.footnote)
            }
            Section("Temporary shared cache") {
                Text("The shared service can reuse nearby forecasts for up to two hours and within 30 kilometres. Apple's earlier expiry takes precedence. Nearby weather may differ; this is not a guarantee of local accuracy.")
                Text("The planned service uses location only to find weather. It does not build a travel or weather history. Live location sharing remains off in this preview.")
            }
        }
        .foregroundStyle(.primary).navigationTitle("Weather")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .accessibilityIdentifier("weatherInformation")
    }
}

/// Keep external attribution links behind the same grown-up UI task as other
/// source links. This task does not authorize location sharing or live weather.
private struct WeatherSourceLink: View {
    let title: String
    let url: URL
    @Environment(\.openURL) private var openURL
    @State private var parentGate = ParentActionGate()
    private var valid: Bool {
        url.scheme == "https" && ["weatherkit.apple.com", "developer.apple.com"].contains(url.host ?? "") &&
        url.user == nil && url.password == nil && url.port == nil && url.fragment == nil
    }
    var body: some View {
        Button {
            parentGate.request("Open Apple's weather data sources in the browser. The website has its own privacy policy.") { openURL(url) }
        } label: { Text(title).underline().foregroundStyle(.primary) }
            .buttonStyle(.plain).disabled(!valid)
            .help("View Apple Weather attribution and data providers")
            .accessibilityAddTraits(.isLink).parentActions(parentGate)
    }
}
#endif
