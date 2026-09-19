import CoreLocation
import MapKit
import Observation
import SwiftUI

@MainActor
@Observable
final class LocationPickerViewModel: NSObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var currentLocation: CLLocation?
    var errorMessage: String?

    override init() {
        super.init()
        locationManager.delegate = self
        authorizationStatus = locationManager.authorizationStatus
    }

    func requestCurrentLocation() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            locationManager.requestLocation()
        default:
            errorMessage = "Location access is disabled in Settings."
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentLocation = locations.last
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        errorMessage = error.localizedDescription
    }
}

struct LocationPickerView: View {
    @Binding var location: ExpenseLocation?
    @State private var viewModel = LocationPickerViewModel()
    @State private var position: MapCameraPosition

    init(location: Binding<ExpenseLocation?>) {
        _location = location
        if let value = location.wrappedValue {
            _position = State(initialValue: .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: value.latitude, longitude: value.longitude),
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )))
        } else {
            _position = State(initialValue: .automatic)
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            MapReader { proxy in
                Map(position: $position) {
                    if let location {
                        Marker(location.name.isEmpty ? "Selected location" : location.name,
                               coordinate: CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude))
                    }
                }
                .onTapGesture { point in
                    guard let coordinate = proxy.convert(point, from: .local) else { return }
                    location = ExpenseLocation(latitude: coordinate.latitude, longitude: coordinate.longitude, name: "Selected location")
                }
                .onMapCameraChange(frequency: .onEnd) { context in
                    guard location != nil else { return }
                    let coordinate = context.region.center
                    location?.latitude = coordinate.latitude
                    location?.longitude = coordinate.longitude
                }
            }
            .frame(height: 220)
            .clipShape(.rect(cornerRadius: 18))

            Button("Use current location", systemImage: "location.fill") {
                viewModel.requestCurrentLocation()
            }
            .buttonStyle(.bordered)
        }
        .onAppear { viewModel.requestCurrentLocation() }
        .onChange(of: viewModel.currentLocation) { _, newValue in
            guard let coordinate = newValue?.coordinate else { return }
            location = ExpenseLocation(latitude: coordinate.latitude, longitude: coordinate.longitude, name: "Current location")
            position = .region(MKCoordinateRegion(center: coordinate, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)))
        }
        .alert("Location unavailable", isPresented: .init(get: { viewModel.errorMessage != nil }, set: { if !$0 { viewModel.errorMessage = nil } })) {
            Button("OK", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

}

struct LocationMapPreview: View {
    let location: ExpenseLocation
    @State private var position: MapCameraPosition

    init(location: ExpenseLocation) {
        self.location = location
        let coordinate = CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
        _position = State(initialValue: .region(MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )))
    }

    var body: some View {
        Map(position: $position) {
            Marker(
                location.name.isEmpty ? "Selected location" : location.name,
                coordinate: CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
            )
        }
        .frame(height: 150)
        .clipShape(.rect(cornerRadius: 16))
        .allowsHitTesting(false)
    }
}
