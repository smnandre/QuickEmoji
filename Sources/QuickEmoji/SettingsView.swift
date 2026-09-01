import SwiftUI

@MainActor
struct SettingsView: View {
    @State private var settings = AppSettings.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.string("Settings"))
                .font(.headline)

            Toggle(
                L10n.string("Launch at Login"),
                isOn: Binding(
                    get: { settings.launchAtLoginStatus == .enabled },
                    set: { settings.setLaunchAtLogin($0) }
                )
            )
            .toggleStyle(.switch)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 18)
        .frame(width: 340, alignment: .leading)
    }
}
