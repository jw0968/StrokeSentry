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
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.5)
                            
                            Text("Finding nearby hospitals...")
                                .font(.title3)
                                .foregroundColor(.white)
                        }
                    } else if hospitals.isEmpty && !isLoading && !showingError {
                        VStack(spacing: 20) {
                            Image(systemName: "location.slash")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                            
                            Text("Location Required")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                            
                            Text("We need your location to find nearby hospitals")
                                .font(.body)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                            
                            Button("Try Again") {
                                setupLocationAndSearch()
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 30)
                            .padding(.vertical, 15)
                            .background(Color.blue)
                            .cornerRadius(25)
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
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Refresh") {
                        searchHospitals()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .onAppear {
            setupLocationAndSearch()
        }
        .alert("Location Error", isPresented: $showingError) {
            Button("OK") {
                showingError = false
            }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func setupLocationAndSearch() {
        print("HospitalsView: Setting up location and search...")
        
        if !CLLocationManager.locationServicesEnabled() {
            print("HospitalsView: Location services are disabled")
            showError("Location Error: Please ensure location services and app permissions are enabled")
            return
        }
        
        locationManager.requestLocation { success in
            print("HospitalsView: Location request result: \(success)")
            
            if success {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    if let location = self.locationManager.currentLocation {
                        print("HospitalsView: Location received, updating region and searching hospitals")
                        self.region.center = location.coordinate
                        self.searchHospitals()
                    } else {
                        print("HospitalsView: No location available after delay")
                        self.showError("Location Error: Please ensure location services and app permissions are enabled")
                    }
                }
            } else {
                print("HospitalsView: Location request failed")
                self.showError("Location Error: Please ensure location services and app permissions are enabled")
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
                        .foregroundColor(.white)
                    
                    Text(hospital.address)
                        .font(.caption)
                        .foregroundColor(.gray)
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
                    .foregroundColor(.white)
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
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        authorizationStatus = locationManager.authorizationStatus
    }
    
    func requestLocation(completion: @escaping (Bool) -> Void) {
        print("LocationManager: Requesting location...")
        print("LocationManager: Current authorization status: \(authorizationStatus.rawValue)")
        
        switch authorizationStatus {
        case .notDetermined:
            print("LocationManager: Requesting authorization...")
            locationManager.requestWhenInUseAuthorization()
            completion(true)
        case .authorizedWhenInUse, .authorizedAlways:
            print("LocationManager: Authorization granted, requesting location...")
            locationManager.requestLocation()
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
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("LocationManager: Location error: \(error.localizedDescription)")
        if let clError = error as? CLError {
            print("LocationManager: Core Location error code: \(clError.code.rawValue)")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        print("LocationManager: Authorization status changed to: \(status.rawValue)")
        authorizationStatus = status
        
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            print("LocationManager: Authorization granted, requesting location...")
            locationManager.requestLocation()
        }
    }
}

#Preview {
    HospitalsView()
} 