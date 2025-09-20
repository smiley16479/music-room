// Exemple d'initialisation dans ton App.swift ou ContentView.swift

/* import SwiftUI

@main
struct MusicRoomApp: App {
    // Initialise le service socket au démarrage de l'app
    init() {
        // Démarre la connexion socket
        _ = SocketService.shared
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(SocketService.shared) // Optionnel si tu veux l'injecter
        }
    }
}

// Ou dans ton ContentView si tu préfères
struct ContentView: View {
    @StateObject private var socketService = SocketService.shared
    
    var body: some View {
        // Tes vues existantes
        TabView {
            // ...
        }
        .onAppear {
            // Le service se connecte automatiquement
        }
        .onDisappear {
            // Optionnel: déconnecte quand l'app se ferme
            socketService.disconnect()
        }
    }
}

// Exemple d'utilisation dans une vue qui a besoin des sockets
struct ExampleSocketUsageView: View {
    @ObservedObject private var socketService = SocketService.shared
    
    var body: some View {
        VStack {
            if socketService.isConnected {
                Text("🟢 Connecté au serveur")
                    .foregroundColor(.green)
            } else {
                Text("🔴 Déconnecté")
                    .foregroundColor(.red)
            }
            
            if let room = socketService.currentRoom {
                Text("Room: \(room)")
            }
            
            Button("Test Socket") {
                socketService.emit(.trackVoted, data: ["test": "message"])
            }
        }
    }
}
 */