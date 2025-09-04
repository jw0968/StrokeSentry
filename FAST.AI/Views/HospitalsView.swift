//
//  HospitalsView.swift
//  FAST.AI
//
//  Created by Jerry Wang Admin on 6/18/25.
//

import SwiftUI
import MapKit
import CoreLocation

struct HospitalsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var locationManager = LocationManager()
    @State private var hospitals: [Hospital] = []
    @State private var isLoading = true
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
    )
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.white.ignoresSafeArea()
                
                VStack {
                    if isLoading {
                        VStack(spacing: 20) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                .scaleEffect(1.5)
                            
                            Text("Finding nearby hospitals...")
                                .font(.title3)
                                .foregroundColor(.black)
                        }
                    } else if hospitals.isEmpty && !isLoading && !showingError {
                        VStack(spacing: 20) {
                            Image(systemName: "location.slash")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                            
                            Text("Location Required")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.black)
                            
                            Text("We need your location to find nearby hospitals")
                                .font(.body)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                            
                            VStack(spacing: 12) {
                                Button("Try Again") {
                                    setupLocationAndSearch()
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 30)
                                .padding(.vertical, 15)
                                .background(Color.blue)
                                .cornerRadius(25)
                                
                                if locationManager.authorizationStatus == .denied || locationManager.authorizationStatus == .restricted {
                                    Button("Open Settings") {
                                        openSettings()
                                    }
                                    .foregroundColor(.blue)
                                    .padding(.horizontal, 30)
                                    .padding(.vertical, 15)
                                    .background(Color.white.opacity(0.2))
                                    .cornerRadius(25)
                                }
                            }
                        }
                    } else {
                        VStack(spacing: 0) {
                            Map(coordinateRegion: $region, annotationItems: hospitals) { hospital in
                                MapAnnotation(coordinate: hospital.coordinate) {
                                    VStack(spacing: 4) {
                                        Image(systemName: "cross.fill")
                                            .font(.title2)
                                            .foregroundColor(.red)
                                            .background(
                                                Circle()
                                                    .fill(.white)
                                                    .frame(width: 30, height: 30)
                                            )
                                        
                                        Text(hospital.name)
                                            .font(.caption)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.black.opacity(0.7))
                                            .cornerRadius(8)
                                    }
                                }
                            }
                            .frame(height: 300)
                            
                            ScrollView {
                                LazyVStack(spacing: 12) {
                                    ForEach(hospitals) { hospital in
                                        HospitalCard(hospital: hospital)
                                    }
                                }
                                .padding()
                            }
                        }
                    }
                }
            }
            .navigationTitle("Nearby Hospitals")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") {
                        dismiss()
                    }
                    .foregroundColor(.black)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Refresh") {
                        searchHospitals()
                    }
                    .foregroundColor(.black)
                }
            }
        }
        .onAppear {
            setupLocationAndSearch()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            // Refresh location status when app becomes active (e.g., returning from Settings)
            if locationManager.authorizationStatus == .authorizedWhenInUse || locationManager.authorizationStatus == .authorizedAlways {
                setupLocationAndSearch()
            }
        }
        .alert("Location Error", isPresented: $showingError) {
            Button("OK") {
                showingError = false
            }
            
            if locationManager.authorizationStatus == .denied || locationManager.authorizationStatus == .restricted {
                Button("Open Settings") {
                    openSettings()
                }
            }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func setupLocationAndSearch() {
        print("HospitalsView: Setting up location and search...")
        
        // Check permissions first
        guard checkLocationPermissions() else {
            return
        }
        
        locationManager.requestLocation { success in
            print("HospitalsView: Location request result: \(success)")
            
            if success {
                // Wait a bit for the location to be updated
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if let location = self.locationManager.currentLocation {
                        print("HospitalsView: Location received, updating region and searching hospitals")
                        self.region.center = location.coordinate
                        self.searchHospitals()
                    } else {
                        print("HospitalsView: No location available after delay")
                        self.showError("Unable to get your current location. Please try again or check your device settings.")
                    }
                }
            } else {
                print("HospitalsView: Location request failed")
                // Check if it's an authorization issue
                if self.locationManager.authorizationStatus == .denied || self.locationManager.authorizationStatus == .restricted {
                    self.showError("Location access denied. Please enable location permissions in Settings.")
                } else if !CLLocationManager.locationServicesEnabled() {
                    self.showError("Location services are disabled. Please enable them in Settings.")
                } else {
                    self.showError("Unable to get your location. Please check your device settings and try again.")
                }
            }
        }
    }
    
    private func searchHospitals() {
        isLoading = true
        
        guard let location = locationManager.currentLocation else {
            showError("Location Error: Please ensure location services and app permissions are enabled")
            isLoading = false
            return
        }
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "hospital"
        request.region = MKCoordinateRegion(
            center: location.coordinate,
            latitudinalMeters: 32186.9,
            longitudinalMeters: 32186.9
        )
        
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            DispatchQueue.main.async {
                isLoading = false
                
                if let error = error {
                    showError("Error searching for hospitals: \(error.localizedDescription)")
                    return
                }
                
                guard let response = response else {
                    showError("No hospitals found nearby")
                    return
                }
                
                hospitals = response.mapItems.compactMap { item in
                    guard let name = item.name,
                          let coordinate = item.placemark.location?.coordinate else {
                        return nil
                    }
                    
                    let distance = location.distance(from: item.placemark.location ?? location)
                    let distanceInMiles = distance * 0.000621371
                    
                    return Hospital(
                        name: name,
                        address: formatAddress(item.placemark),
                        coordinate: coordinate,
                        distance: distanceInMiles,
                        phone: item.phoneNumber
                    )
                }.sorted { $0.distance < $1.distance }
                
                if hospitals.isEmpty {
                    showError("No hospitals found within 20 miles")
                }
            }
        }
    }
    
    private func formatAddress(_ placemark: MKPlacemark) -> String {
        var components: [String] = []
        
        if let thoroughfare = placemark.thoroughfare {
            components.append(thoroughfare)
        }
        if let subThoroughfare = placemark.subThoroughfare {
            components.append(subThoroughfare)
        }
        if let locality = placemark.locality {
            components.append(locality)
        }
        if let administrativeArea = placemark.administrativeArea {
            components.append(administrativeArea)
        }
        
        return components.joined(separator: ", ")
    }
    
    private func showError(_ message: String) {
        errorMessage = message
        showingError = true
    }
    
    private func checkLocationPermissions() -> Bool {
        if !CLLocationManager.locationServicesEnabled() {
            showError("Location services are disabled. Please enable them in Settings > Privacy & Security > Location Services.")
            return false
        }
        
        switch locationManager.authorizationStatus {
        case .denied, .restricted:
            showError("Location access denied. Please enable location permissions in Settings > Privacy & Security > Location Services > StrokeSentry.")
            return false
        case .notDetermined:
            // Will request permission
            return true
        case .authorizedWhenInUse, .authorizedAlways:
            return true
        @unknown default:
            showError("Unknown location authorization status. Please check your device settings.")
            return false
        }
    }
    
    private func openSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
}

struct HospitalCard: View {
    let hospital: Hospital
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(hospital.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.black)
                    
                    Text(hospital.address)
                        .font(.caption)
                        .foregroundColor(.black)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(String(format: "%.1f mi", hospital.distance))
                        .font(.caption)
                        .foregroundColor(.green)
                    
                    if let phone = hospital.phone {
                        Button(action: {
                            if let url = URL(string: "tel:\(phone)") {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            Image(systemName: "phone.fill")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            
            HStack {
                Button(action: {
                    openInMaps()
                }) {
                    HStack {
                        Image(systemName: "map.fill")
                        Text("Directions")
                    }
                    .font(.caption)
                    .foregroundColor(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.3))
                    .cornerRadius(8)
                }
                
                Spacer()
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    private func openInMaps() {
        let placemark = MKPlacemark(coordinate: hospital.coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = hospital.name
        mapItem.openInMaps(launchOptions: nil)
    }
}

struct Hospital: Identifiable {
    let id = UUID()
    let name: String
    let address: String
    let coordinate: CLLocationCoordinate2D
    let distance: Double
    let phone: String?
}

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    private var locationCompletion: ((Bool) -> Void)?
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        // Use the current authorization status from the manager
        authorizationStatus = locationManager.authorizationStatus
    }
    
    func requestLocation(completion: @escaping (Bool) -> Void) {
        print("LocationManager: Requesting location...")
        print("LocationManager: Current authorization status: \(authorizationStatus.rawValue)")
        
        // Store the completion handler
        locationCompletion = completion
        
        // Check if location services are enabled at the system level
        guard CLLocationManager.locationServicesEnabled() else {
            print("LocationManager: Location services are disabled at system level")
            completion(false)
            return
        }
        
        switch authorizationStatus {
        case .notDetermined:
            print("LocationManager: Requesting authorization...")
            locationManager.requestWhenInUseAuthorization()
            // Don't call completion here - wait for authorization change
        case .authorizedWhenInUse, .authorizedAlways:
            print("LocationManager: Authorization granted, requesting location...")
            locationManager.requestLocation()
            
            // Set a timeout for location request
            DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
                if let completion = self.locationCompletion {
                    print("LocationManager: Location request timed out")
                    completion(false)
                    self.locationCompletion = nil
                }
            }
            
            completion(true)
        case .denied, .restricted:
            print("LocationManager: Location access denied or restricted")
            completion(false)
        @unknown default:
            print("LocationManager: Unknown authorization status")
            completion(false)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        print("LocationManager: Location updated - \(locations.count) locations received")
        if let location = locations.first {
            print("LocationManager: Location - lat: \(location.coordinate.latitude), lon: \(location.coordinate.longitude)")
            currentLocation = location
            
            // If we have a pending completion handler, call it
            if let completion = locationCompletion {
                completion(true)
                locationCompletion = nil
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("LocationManager: Location error: \(error.localizedDescription)")
        if let clError = error as? CLError {
            print("LocationManager: Core Location error code: \(clError.code.rawValue)")
            
            // Handle specific location errors
            switch clError.code {
            case .denied:
                print("LocationManager: Location access denied")
            case .locationUnknown:
                print("LocationManager: Location temporarily unavailable")
            case .network:
                print("LocationManager: Network error")
            case .headingFailure:
                print("LocationManager: Heading failure")
            case .rangingUnavailable:
                print("LocationManager: Ranging unavailable")
            default:
                print("LocationManager: Other location error: \(clError.code.rawValue)")
            }
        }
        
        // If we have a pending completion handler, call it with failure
        if let completion = locationCompletion {
            completion(false)
            locationCompletion = nil
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        print("LocationManager: Authorization status changed to: \(status.rawValue)")
        authorizationStatus = status
        
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            print("LocationManager: Authorization granted, requesting location...")
            locationManager.requestLocation()
        case .denied, .restricted:
            print("LocationManager: Authorization denied or restricted")
            // If we have a pending completion handler, call it with failure
            if let completion = locationCompletion {
                completion(false)
                locationCompletion = nil
            }
        case .notDetermined:
            print("LocationManager: Authorization not determined")
        @unknown default:
            print("LocationManager: Unknown authorization status")
        }
    }
}

#Preview {
    HospitalsView()
} 
