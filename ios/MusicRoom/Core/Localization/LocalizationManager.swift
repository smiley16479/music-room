import SwiftUI
import Foundation

class LocalizationManager: ObservableObject {
    @Published var currentLanguage: String {
        didSet {
            UserDefaults.standard.set(currentLanguage, forKey: "selectedLanguage")
            // Force UI update
            Bundle.setLanguage(currentLanguage)
        }
    }
    
    static let supportedLanguages = ["en", "fr"]
    static let languageNames = ["en": "English", "fr": "Français"]
    
    init() {
        // Check if user has previously selected a language
        let savedLanguage = UserDefaults.standard.string(forKey: "selectedLanguage")
        
        if let savedLanguage = savedLanguage, Self.supportedLanguages.contains(savedLanguage) {
            self.currentLanguage = savedLanguage
        } else {
            // Auto-detect system language
            let preferredLanguage = Locale.preferredLanguages.first ?? "en"
            let languageCode = String(preferredLanguage.prefix(2))
            self.currentLanguage = Self.supportedLanguages.contains(languageCode) ? languageCode : "en"
        }
        
        Bundle.setLanguage(currentLanguage)
    }
    
    func setLanguage(_ language: String) {
        guard Self.supportedLanguages.contains(language) else { return }
        currentLanguage = language
    }
    
    func localizedString(for key: String) -> String {
        return NSLocalizedString(key, comment: "")
    }
}

// MARK: - Bundle Extension for Language Change
extension Bundle {
    static func setLanguage(_ language: String) {
        // For iOS 13+ and modern SwiftUI, we rely on system locale changes
        // This is a simplified approach that works better with modern iOS
        UserDefaults.standard.set([language], forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()
    }
}

// MARK: - Localization Helper
struct LocalizedStringKey {
    let key: String
    
    init(_ key: String) {
        self.key = key
    }
}

extension String {
    var localized: String {
        return NSLocalizedString(self, comment: "")
    }
    
    func localized(with arguments: CVarArg...) -> String {
        return String(format: NSLocalizedString(self, comment: ""), arguments: arguments)
    }
}
