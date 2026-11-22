import SwiftUI

@main
struct S23KeyboardApp: App {
    var body: some Scene {
        WindowGroup { SetupView() }
    }
}

struct SetupView: View {
    @State private var sample = ""
    var body: some View {
        NavigationStack {
            Form {
                Section("Enable your keyboard") {
                    Text("Open Settings → General → Keyboard → Keyboards → Add New Keyboard → S23 Style.")
                    Text("Then hold the globe key in any text field and choose S23 Style.")
                    Text("For haptics and clipboard capture, select S23 Style in that keyboard list and turn on Allow Full Access. This build sends no text over the network.")
                    Text("The keyboard saves copied text and images when it opens or is visible. iOS may also ask you to allow pasting.")
                }
                Section("Try it here") {
                    NavigationLink("Open keyboard test") { KeyboardLab().navigationTitle("Typing test").navigationBarTitleDisplayMode(.inline) }
                    TextEditor(text: $sample).frame(minHeight: 180)
                }
                Section("Customize while typing") {
                    Text("Tap the gear on the keyboard to adjust key highlights, sound, haptic strength, and keyboard height.")
                }
                Section("Version 0.3") {
                    Text("Touch feedback, character previews, hold-and-slide symbols and accents, cursor movement, and a 50-item text/image clipboard. ClipKey and S23 keep separate saved histories.")
                    Text("Translation, AI rewriting, swipe typing, and dictation are not implemented.")
                }
            }.navigationTitle("Your keyboard")
        }
    }
}
