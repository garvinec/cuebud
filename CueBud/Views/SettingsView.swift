import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @AppStorage("maxFillersPerMinute") private var maxFillers: Int = 3
    @AppStorage("maxWPM") private var maxWPM: Double = 170
    @AppStorage("minWPM") private var minWPM: Double = 100
    @AppStorage("ramblingThreshold") private var ramblingThreshold: Double = 90
    @AppStorage("tipCooldown") private var tipCooldown: Double = 90
    @AppStorage("showPostureTips") private var showPostureTips = true
    @AppStorage("showSpeechTips") private var showSpeechTips = true

    private static let speechTipTypes: [TipType] = [.fillerWords, .speakingTooFast, .speakingTooSlow, .tooQuiet, .rambling]
    private static let postureTipTypes: [TipType] = [.slouching, .notLookingAtCamera, .notSmiling, .headTilt, .tooClose, .tooFar]

    private func tipEnabledBinding(for type: TipType) -> Binding<Bool> {
        let key = "tipEnabled_\(type.rawValue)"
        return Binding(
            get: { UserDefaults.standard.object(forKey: key) == nil ? true : UserDefaults.standard.bool(forKey: key) },
            set: { UserDefaults.standard.set($0, forKey: key) }
        )
    }

    var body: some View {
        if auth.currentUser != nil {
            signedInForm
        } else {
            signedOutForm
        }
    }

    private var signedOutForm: some View {
        Form {
            Section("Account") {
                Button("Sign In with Google") {
                    NSApp.keyWindow?.close()
                    Task {
                        try? await auth.signInWithGoogle()
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 100)
    }

    private var signedInForm: some View {
        Form {
            Section("Account") {
                if let user = auth.currentUser {
                    LabeledContent("Email", value: user.email)

                    if let joinedAt = user.joinedAt {
                        LabeledContent("Member since", value: joinedAt.formatted(.dateTime.month(.wide).day().year()))
                    }

                    LabeledContent("Plan", value: user.tier.capitalized)

                    if !subscriptionManager.isPro {
                        LabeledContent("Sessions remaining", value: "\(subscriptionManager.sessionsRemaining)")
                    }
                }

                Button(role: .destructive) {
                    NSApp.keyWindow?.close()
                    auth.signOut()
                } label: {
                    Text("Sign Out")
                }
            }

            Section("Speech Coaching") {
                Toggle("Enable speech tips", isOn: $showSpeechTips)

                ForEach(SettingsView.speechTipTypes, id: \.self) { type in
                    Toggle(type.displayName, isOn: tipEnabledBinding(for: type))
                }
                .disabled(!showSpeechTips)

                Stepper("Max fillers before alert: \(maxFillers)/min", value: $maxFillers, in: 1...10)
                    .disabled(!showSpeechTips)

                HStack {
                    Text("Fast speech threshold")
                    Spacer()
                    Text("\(Int(maxWPM)) WPM")
                        .foregroundColor(.secondary)
                }
                Slider(value: $maxWPM, in: 130...220, step: 10)
                    .disabled(!showSpeechTips)

                HStack {
                    Text("Slow speech threshold")
                    Spacer()
                    Text("\(Int(minWPM)) WPM")
                        .foregroundColor(.secondary)
                }
                Slider(value: $minWPM, in: 60...130, step: 10)
                    .disabled(!showSpeechTips)

                HStack {
                    Text("Rambling threshold")
                    Spacer()
                    Text("\(Int(ramblingThreshold))s")
                        .foregroundColor(.secondary)
                }
                Slider(value: $ramblingThreshold, in: 30...180, step: 10)
                    .disabled(!showSpeechTips)
            }

            Section("Posture Coaching") {
                Toggle("Enable posture tips", isOn: $showPostureTips)

                ForEach(SettingsView.postureTipTypes, id: \.self) { type in
                    Toggle(type.displayName, isOn: tipEnabledBinding(for: type))
                }
                .disabled(!showPostureTips)
            }

            Section("General") {
                HStack {
                    Text("Tip cooldown")
                    Spacer()
                    Text("\(Int(tipCooldown))s")
                        .foregroundColor(.secondary)
                }
                Slider(value: $tipCooldown, in: 30...180, step: 10)
                Text("How long to wait before showing the same cue again after you dismiss it.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 400, maxWidth: 400, minHeight: 560)
    }
}
