import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var auth: AuthService
    @AppStorage("maxFillersPerMinute") private var maxFillers: Int = 3
    @AppStorage("maxWPM") private var maxWPM: Double = 170
    @AppStorage("minWPM") private var minWPM: Double = 100
    @AppStorage("ramblingThreshold") private var ramblingThreshold: Double = 90
    @AppStorage("tipCooldown") private var tipCooldown: Double = 90
    @AppStorage("showPostureTips") private var showPostureTips = true
    @AppStorage("showSpeechTips") private var showSpeechTips = true

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
                Button("Sign In") {
                    NSApp.keyWindow?.close()
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

                Stepper("Max fillers before alert: \(maxFillers)/min", value: $maxFillers, in: 1...10)

                HStack {
                    Text("Fast speech threshold")
                    Spacer()
                    Text("\(Int(maxWPM)) WPM")
                        .foregroundColor(.secondary)
                }
                Slider(value: $maxWPM, in: 130...220, step: 10)

                HStack {
                    Text("Slow speech threshold")
                    Spacer()
                    Text("\(Int(minWPM)) WPM")
                        .foregroundColor(.secondary)
                }
                Slider(value: $minWPM, in: 60...130, step: 10)

                HStack {
                    Text("Rambling threshold")
                    Spacer()
                    Text("\(Int(ramblingThreshold))s")
                        .foregroundColor(.secondary)
                }
                Slider(value: $ramblingThreshold, in: 30...180, step: 10)
            }

            Section("Posture Coaching") {
                Toggle("Enable posture tips", isOn: $showPostureTips)
            }

            Section("General") {
                HStack {
                    Text("Tip cooldown")
                    Spacer()
                    Text("\(Int(tipCooldown))s")
                        .foregroundColor(.secondary)
                }
                Slider(value: $tipCooldown, in: 30...180, step: 10)
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 540)
    }
}
