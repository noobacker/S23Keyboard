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
                    Text("Basic typing works without Full Access. Importing copied text into the saved clipboard requires Full Access. This build sends no text over the network.")
                }
                Section("Try it here") {
                    TextEditor(text: $sample).frame(minHeight: 180)
                }
                Section("Customize while typing") {
                    Text("Tap the gear on the keyboard to adjust key highlights, sound, haptic strength, and keyboard height.")
                }
                Section("Version 0.1") {
                    Text("A first native prototype based on your reference photo. Translation, AI rewriting, swipe typing, and dictation are not implemented yet.")
                }
            }.navigationTitle("Your keyboard")
        }
    }
}
