//
//  LocationManager.swift
//  music-room
//
//  Created by adrien on 18/08/2025.
//

import CoreLocation

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationManager()
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
    
    func getLongLatFromAddressString(place: String, completion: @escaping (CLLocationCoordinate2D?) -> Void) {
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(place) { placemarks, error in
            if let location = placemarks?.first?.location {
                completion(location.coordinate)
            } else {
                completion(nil)
            }
        }
    }
    
    /// Retourne true si la distance entre deux points est inférieure ou égale au rayon donné (en mètres)
    func isWithinRadius(userCoord: CLLocationCoordinate2D, eventCoord: CLLocationCoordinate2D, radius: Double) -> Bool {
        let userLocation = CLLocation(latitude: userCoord.latitude, longitude: userCoord.longitude)
        let eventLocation = CLLocation(latitude: eventCoord.latitude, longitude: eventCoord.longitude)
        let distanceMeters = userLocation.distance(from: eventLocation)
        return distanceMeters <= radius
    }
}
