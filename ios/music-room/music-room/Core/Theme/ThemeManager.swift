import SwiftUI
import Combine

class ThemeManager: ObservableObject {
    @Published var isDarkMode: Bool {
        didSet {
            UserDefaults.standard.set(isDarkMode, forKey: "isDarkMode")
        }
    }
    
    var colorScheme: ColorScheme? {
        isDarkMode ? .dark : .light
    }
    
    init() {
        self.isDarkMode = UserDefaults.standard.bool(forKey: "isDarkMode")
    }
    
    func toggleTheme() {
        isDarkMode.toggle()
    }
}

// MARK: - Theme Colors
extension Color {
    static let section1Color = Color("Section1Color")
    static let section2Color = Color("Section2Color")
    static let section3Color = Color("Section3Color")
    
    // Music theme colors
    static let musicPrimary = Color.section3Color
    static let musicSecondary = Color.section2Color
    static let musicBackground = Color.section1Color
    
    // Additional theme colors
    static let cardBackground = Color(.systemBackground)
    static let secondaryBackground = Color(.secondarySystemBackground)
    static let textPrimary = Color(.label)
    static let textSecondary = Color(.secondaryLabel)
}
