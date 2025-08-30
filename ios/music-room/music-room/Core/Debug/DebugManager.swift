//
//  DebugManager.swift
//  music-room
//
//  Created by adrien on 30/08/2025.
//


import Foundation

class DebugManager: ObservableObject {
    static let shared = DebugManager()
    @Published var isDebugEnabled: Bool = false
    private init() {}
}