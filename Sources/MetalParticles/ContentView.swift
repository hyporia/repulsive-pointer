import SwiftUI

@available(macOS 14.0, *)
struct ContentView: View {
    var body: some View {
        MetalView()
            .edgesIgnoringSafeArea(.all)
            .frame(minWidth: 800, minHeight: 600)
    }
}
