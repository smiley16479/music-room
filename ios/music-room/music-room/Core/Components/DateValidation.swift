import SwiftUI
import Foundation

// MARK: - Date Validation Logic
struct DateValidation {
    static func isValid(startDate: Date, endDate: Date) -> Bool {
        return endDate > startDate
    }
    
    static func validationMessage(startDate: Date, endDate: Date) -> String? {
        if endDate <= startDate {
            return "La date de fin doit être après la date de début"
        }
        if startDate < Date() {
            return "La date de l'événement ne peut pas être dans le passé"
        }
        return nil
    }
    
    static func adjustEndDate(for startDate: Date, currentEndDate: Date, defaultHoursToAdd: Int = 2) -> Date {
        if currentEndDate <= startDate {
            return Calendar.current.date(byAdding: .hour, value: defaultHoursToAdd, to: startDate) ?? startDate
        }
        return currentEndDate
    }
    
    static func formatDuration(from startDate: Date, to endDate: Date) -> String {
        let duration = endDate.timeIntervalSince(startDate)
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        return "Durée: \(hours)h \(minutes)min"
    }
}

// MARK: - Reusable Date Section Component
struct EventDateSection: View {
    @Binding var startDate: Date
    @Binding var endDate: Date
    @Binding var location: String
    @Binding var radius: Double

    private var startDateRange: PartialRangeFrom<Date> {
        showPastDateValidation ? Date()... : Date.distantPast...
    }

    let showPastDateValidation: Bool
    let minimumDurationHours: Int

    init(
        startDate: Binding<Date>,
        endDate: Binding<Date>,
        location: Binding<String>,
        radius: Binding<Double>,
        showPastDateValidation: Bool = true,
        minimumDurationHours: Int = 1
    ) {
      print("radius: \(radius.wrappedValue)")
        self._startDate = startDate
        self._endDate = endDate
        self._location = location
        self._radius = radius
        self.showPastDateValidation = showPastDateValidation
        self.minimumDurationHours = minimumDurationHours
    }
    
    private var validationMessage: String? {
        if showPastDateValidation && startDate < Date() {
            return "La date de l'événement ne peut pas être dans le passé"
        }
        if endDate <= startDate {
            return "La date de fin doit être après la date de début"
        }
        if endDate.timeIntervalSince(startDate) < TimeInterval(minimumDurationHours * 3600) {
            return "L'événement doit durer au moins \(minimumDurationHours) heure\(minimumDurationHours > 1 ? "s" : "")"
        }
        return nil
    }
    
    private var isDateValid: Bool {
        validationMessage == nil
    }
    
    var body: some View {
        Section(header: Text("Location & Date")) {
            TextField("Location", text: $location)
            Stepper(value: $radius, in: 100...10000, step: 50) {
                Text("Rayon : \(Int(radius)) m")
            }
            Slider(value: $radius, in: 100...10000, step: 50).accentColor(.musicPrimary)
            DatePicker(
                "Date de début",
                selection: $startDate,
                in: startDateRange,
                displayedComponents: [.date, .hourAndMinute]
            )
            .onChange(of: startDate) { oldValue, newValue in
                endDate = DateValidation.adjustEndDate(
                    for: newValue,
                    currentEndDate: endDate,
                    defaultHoursToAdd: 2
                )
            }
            DatePicker(
                "Date de fin",
                selection: $endDate,
                in: startDate...,
                displayedComponents: [.date, .hourAndMinute]
            )
            // Affichage de la durée si les dates sont valides
            if isDateValid && endDate > startDate {
                Text(DateValidation.formatDuration(from: startDate, to: endDate))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            // Message d'erreur si dates invalides
            if let errorMessage = validationMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }
}

// MARK: - Date Validation Helper for ViewModels
@Observable
class EventDateValidator {
    var startDate: Date = Date()
    var endDate: Date = Date()
    
    var isValid: Bool {
        DateValidation.isValid(startDate: startDate, endDate: endDate)
    }
    
    var validationMessage: String? {
        DateValidation.validationMessage(startDate: startDate, endDate: endDate)
    }
    
    init(startDate: Date = Date(), endDate: Date? = nil) {
        self.startDate = startDate
        self.endDate = endDate ?? Calendar.current.date(byAdding: .hour, value: 2, to: startDate) ?? startDate
    }
    
    func updateStartDate(_ newDate: Date) {
        startDate = newDate
        endDate = DateValidation.adjustEndDate(for: newDate, currentEndDate: endDate)
    }
    
    func updateEndDate(_ newDate: Date) {
        endDate = newDate
    }
}
