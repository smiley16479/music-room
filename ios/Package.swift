// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MusicRoom",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "MusicRoom",
            targets: ["MusicRoom"]
        ),
    ],
    dependencies: [
        // Socket.IO Client for real-time communication
        .package(url: "https://github.com/socketio/socket.io-client-swift", from: "16.1.0"),
        
        // Google Sign-In SDK
        .package(url: "https://github.com/google/GoogleSignIn-iOS", from: "7.0.0"),
        
        // Facebook SDK
        .package(url: "https://github.com/facebook/facebook-ios-sdk", from: "16.0.0"),
        
        // Keychain wrapper for secure storage
        .package(url: "https://github.com/evgenyneu/keychain-swift", from: "20.0.0"),
    ],
    targets: [
        .target(
            name: "MusicRoom",
            dependencies: [
                .product(name: "SocketIO", package: "socket.io-client-swift"),
                .product(name: "GoogleSignIn", package: "GoogleSignIn-iOS"),
                .product(name: "FacebookCore", package: "facebook-ios-sdk"),
                .product(name: "FacebookLogin", package: "facebook-ios-sdk"),
                .product(name: "KeychainSwift", package: "keychain-swift"),
            ]
        ),
        .testTarget(
            name: "MusicRoomTests",
            dependencies: ["MusicRoom"]
        ),
    ]
)
