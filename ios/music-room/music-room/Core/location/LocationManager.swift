//
//  LocationManager.swift
//  music-room
//
//  Created by adrien on 18/08/2025.
//

//PAS UTILISÉ POUR LE MOMENT: DESTINÉ À EVENT NEAR_BY
import CoreLocation

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var userLocation: CLLocation?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.requestWhenInUseAuthorization() // ou requestAlwaysAuthorization selon le besoin
        manager.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        userLocation = locations.first
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error)")
    }
    
    func getLongLatFromAddressString(place: String) {
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(place) { placemarks, error in
            guard let location = placemarks?.first?.location else { return }
            print("Latitude: \(location.coordinate.latitude), Longitude: \(location.coordinate.longitude)")
        }
    }
    
    func distBetweenPoints() {
        let userLocation = CLLocation(latitude: 48.8566, longitude: 2.3522) // Paris
        let eventLocation = CLLocation(latitude: 48.8606, longitude: 2.3376) // Musée du Louvre

        let distanceMeters = userLocation.distance(from: eventLocation)
        if distanceMeters <= 1000 {
            print("L'utilisateur est dans le rayon 1km de l'événement")
        }
    }
}
