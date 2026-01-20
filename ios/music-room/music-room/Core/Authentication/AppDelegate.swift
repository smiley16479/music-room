//
//  AppDelegate.swift
//  music-room
//
//  Created by adrien on 08/08/2025.
//


import SwiftUI
import FacebookCore

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        ApplicationDelegate.shared.application(
            application,
            didFinishLaunchingWithOptions: launchOptions
        )
        return true
    }

    // MARK: - FB OAuth
    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey : Any] = [:]
    ) -> Bool {
        ApplicationDelegate.shared.application(
            app,
            open: url,
            options: options
        )
    }
    
// MARK: - Universal Links (depuis un mail par ex.)
//    PAS ENCORE CONFIGURÉ (⚠️nécéssite https⚠️)
    func application(
        _ application: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
    ) -> Bool {
        if userActivity.activityType == NSUserActivityTypeBrowsingWeb,
           let url = userActivity.webpageURL {
            
            print("✅ Universal Link reçu: \(url)")
            
            if url.pathComponents.contains("events") {
                let eventId = url.lastPathComponent
                print("➡️ Ouvrir l’écran Event avec ID: \(eventId)")
                
                // TODO: transmettre `eventId` à ton SwiftUI App
                // ex: NavigationState().openEvent(eventId)
            }
        }
        return true
    }
}
