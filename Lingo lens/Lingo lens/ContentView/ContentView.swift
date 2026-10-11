import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            CameraView()
                .tabItem { Label("カメラ", systemImage: "camera.viewfinder") }
            SavedWordsView()
                .tabItem { Label("単語帳", systemImage: "bookmark") }
        }
    }
}
