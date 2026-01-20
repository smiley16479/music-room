import Foundation
import SwiftUI

// MARK: - Date Extensions
extension Date {
    func timeAgoString() -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.minute, .hour, .day, .weekOfYear, .month, .year], from: self, to: now)
        
        if let years = components.year, years > 0 {
            return years == 1 ? "1 year ago" : "\(years) years ago"
        }
        
        if let months = components.month, months > 0 {
            return months == 1 ? "1 month ago" : "\(months) months ago"
        }
        
        if let weeks = components.weekOfYear, weeks > 0 {
            return weeks == 1 ? "1 week ago" : "\(weeks) weeks ago"
        }
        
        if let days = components.day, days > 0 {
            return days == 1 ? "1 day ago" : "\(days) days ago"
        }
        
        if let hours = components.hour, hours > 0 {
            return hours == 1 ? "1 hour ago" : "\(hours) hours ago"
        }
        
        if let minutes = components.minute, minutes > 0 {
            return minutes == 1 ? "1 minute ago" : "\(minutes) minutes ago"
        }
        
        return "Just now"
    }
    
    func formatted(style: DateFormatter.Style = .medium) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = style
        formatter.timeStyle = .none
        return formatter.string(from: self)
    }

    func formatParisDate() -> String {
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "dd/MM/yyyy HH:mm"
        displayFormatter.timeZone = TimeZone(identifier: "Europe/Paris")
        print("Formatted date: \(displayFormatter.string(from: self))")
        return displayFormatter.string(from: self)
    }
}

// MARK: - String Extensions
extension String: Identifiable {
    public var id: String { self }

    var isValidEmail: Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: self)
    }
    
    var isValidPassword: Bool {
        return count >= 6
    }
    
    func truncated(limit: Int, trailing: String = "...") -> String {
        if count > limit {
            return String(prefix(limit)) + trailing
        }
        return self
    }
    
    func capitalizingFirstLetter() -> String {
        return prefix(1).capitalized + dropFirst()
    }

    func formatParisDate() -> String {
        // Essayer avec ISO8601DateFormatter (plus robuste)
        let iso8601Formatter = ISO8601DateFormatter()
        iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        var date = iso8601Formatter.date(from: self)
        
        // Si ça échoue, essayer sans les millisecondes
        if date == nil {
            iso8601Formatter.formatOptions = [.withInternetDateTime]
            date = iso8601Formatter.date(from: self)
        }
        
        guard let parsedDate = date else {
            print("❌ Failed to parse date: \(self)")
            return self
        }
        
        // Formatage pour l'affichage en heure de Paris
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "dd/MM/yyyy HH:mm"
        displayFormatter.timeZone = TimeZone(identifier: "Europe/Paris") // Forcer UTC pour ne pas reconvertir ou TimeZone(identifier: "UTC")
         
        
        let result = displayFormatter.string(from: parsedDate)
        print("✅ Converted: \(self) -> \(result)")
        return result
    }
}

// MARK: - View Extensions
extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
    
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
    
    func toast(message: String, isShowing: Binding<Bool>, duration: TimeInterval = 2.0) -> some View {
        self.overlay(
            ToastView(message: message, isShowing: isShowing, duration: duration)
        )
    }
}

// MARK: - Color Extensions
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    static func random() -> Color {
        return Color(
            red: Double.random(in: 0...1),
            green: Double.random(in: 0...1),
            blue: Double.random(in: 0...1)
        )
    }
}

// MARK: - Custom Shapes
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Toast View
struct ToastView: View {
    let message: String
    @Binding var isShowing: Bool
    let duration: TimeInterval
    
    var body: some View {
        VStack {
            Spacer()
            
            if isShowing {
                Text(message)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(25)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                            withAnimation {
                                isShowing = false
                            }
                        }
                    }
            }
        }
        .padding(.bottom, 100)
        .animation(.easeInOut, value: isShowing)
    }
}

// MARK: - Array Extensions
extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// MARK: - URL Extensions
extension URL {
    static func makeImageURL(from urlString: String?) -> URL? {
        guard let urlString = urlString, !urlString.isEmpty else {
            return nil
        }
        return URL(string: urlString)
    }
}

// MARK: - UserDefaults Extensions
extension UserDefaults {
    enum Keys: String, CaseIterable {
        case isDarkMode = "isDarkMode"
        case selectedLanguage = "selectedLanguage"
        case pushNotificationsEnabled = "pushNotificationsEnabled"
        case emailNotificationsEnabled = "emailNotificationsEnabled"
        case hasSeenOnboarding = "hasSeenOnboarding"
    }
    
    func set<T>(_ value: T, forKey key: Keys) {
        set(value, forKey: key.rawValue)
    }
    
    func object(forKey key: Keys) -> Any? {
        return object(forKey: key.rawValue)
    }
    
    func string(forKey key: Keys) -> String? {
        return string(forKey: key.rawValue)
    }
    
    func bool(forKey key: Keys) -> Bool {
        return bool(forKey: key.rawValue)
    }
    
    func integer(forKey key: Keys) -> Int {
        return integer(forKey: key.rawValue)
    }
}

// MARK: - Haptic Feedback
struct HapticFeedback {
    static func light() {
        let impactFeedbackgenerator = UIImpactFeedbackGenerator(style: .light)
        impactFeedbackgenerator.prepare()
        impactFeedbackgenerator.impactOccurred()
    }
    
    static func medium() {
        let impactFeedbackgenerator = UIImpactFeedbackGenerator(style: .medium)
        impactFeedbackgenerator.prepare()
        impactFeedbackgenerator.impactOccurred()
    }
    
    static func heavy() {
        let impactFeedbackgenerator = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedbackgenerator.prepare()
        impactFeedbackgenerator.impactOccurred()
    }
    
    static func success() {
        let notificationFeedbackGenerator = UINotificationFeedbackGenerator()
        notificationFeedbackGenerator.prepare()
        notificationFeedbackGenerator.notificationOccurred(.success)
    }
    
    static func warning() {
        let notificationFeedbackGenerator = UINotificationFeedbackGenerator()
        notificationFeedbackGenerator.prepare()
        notificationFeedbackGenerator.notificationOccurred(.warning)
    }
    
    static func error() {
        let notificationFeedbackGenerator = UINotificationFeedbackGenerator()
        notificationFeedbackGenerator.prepare()
        notificationFeedbackGenerator.notificationOccurred(.error)
    }
}
