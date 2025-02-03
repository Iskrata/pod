import SwiftUI
import AVFoundation

struct RadioStation: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let url: String
    let country: String
    
    enum CodingKeys: String, CodingKey {
        case id = "stationuuid"
        case name
        case url
        case country
    }
}

class RadioSettingsViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var searchResults: [RadioStation] = []
    @Published var favoriteStations: [RadioStation] = []
    @Published var selectedStation: RadioStation?
    @Published var isSearching = false
    @Published var errorMessage: String?
    @Published var suggestedStations: [RadioStation] = []
    
    private let baseURL = "https://de1.api.radio-browser.info/json/stations/search"
    
    init() {
        loadFavorites()
        loadSuggestedStations()
    }
    
    func searchStations() {
        guard !searchText.isEmpty else {
            searchResults = []
            return
        }
        
        isSearching = true
        errorMessage = nil
        
        let queryItems = [URLQueryItem(name: "name", value: searchText)]
        var urlComps = URLComponents(string: baseURL)!
        urlComps.queryItems = queryItems
        
        guard let url = urlComps.url else {
            errorMessage = "Invalid search query"
            isSearching = false
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isSearching = false
                
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    return
                }
                
                guard let data = data else {
                    self?.errorMessage = "No data received"
                    return
                }
                
                do {
                    let stations = try JSONDecoder().decode([RadioStation].self, from: data)
                    self?.searchResults = stations
                } catch {
                    self?.errorMessage = "Failed to decode stations"
                }
            }
        }.resume()
    }
    
    func toggleFavorite(_ station: RadioStation) {
        if favoriteStations.contains(station) {
            favoriteStations.removeAll { $0.id == station.id }
        } else {
            favoriteStations.append(station)
        }
        saveFavorites()
    }
    
    func isFavorite(_ station: RadioStation) -> Bool {
        favoriteStations.contains(station)
    }
    
    private func saveFavorites() {
        if let encoded = try? JSONEncoder().encode(favoriteStations) {
            UserDefaults.standard.set(encoded, forKey: "favoriteStations")
        }
    }
    
    private func loadFavorites() {
        if let data = UserDefaults.standard.data(forKey: "favoriteStations"),
           let decoded = try? JSONDecoder().decode([RadioStation].self, from: data) {
            favoriteStations = decoded
        }
    }
    
    func loadSuggestedStations() {
        let url = URL(string: "https://de1.api.radio-browser.info/json/stations/topclick/10")!
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let data = data,
                   let stations = try? JSONDecoder().decode([RadioStation].self, from: data) {
                    self?.suggestedStations = stations
                }
            }
        }.resume()
    }
}

struct RadioSettings: View {
    @StateObject private var viewModel = RadioSettingsViewModel()
    @State private var selectedSidebarItem: String? = "search"
    
    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            // Sidebar
            List(selection: $selectedSidebarItem) {
                NavigationLink(value: "search") {
                    Label("Search", systemImage: "magnifyingglass")
                }
                
                NavigationLink(value: "favorites") {
                    Label("Favorites", systemImage: "heart.fill")
                }
            }
            .listStyle(SidebarListStyle())
            .frame(minWidth: 100, maxWidth: 200)
        } detail: {
            if selectedSidebarItem == "search" {
                SearchContentView(viewModel: viewModel)
            } else {
                FavoritesContentView(viewModel: viewModel)
            }
        }
        .navigationTitle("Radio Stations")
    }
}

struct SearchContentView: View {
    @ObservedObject var viewModel: RadioSettingsViewModel
    
    var body: some View {
        VStack {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search radio stations", text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                    .onSubmit {
                        viewModel.searchStations()
                    }
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)
            .padding()
            
            // Results or Suggestions
            if viewModel.isSearching {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !viewModel.searchText.isEmpty {
                StationsList(stations: viewModel.searchResults, viewModel: viewModel)
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Popular Stations")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    StationsList(stations: viewModel.suggestedStations, viewModel: viewModel)
                }
            }
        }
    }
}

struct StationsList: View {
    let stations: [RadioStation]
    @ObservedObject var viewModel: RadioSettingsViewModel
    
    var groupedStations: [String: [RadioStation]] {
        Dictionary(grouping: stations) { $0.country }
            .sorted(by: { $0.key < $1.key })
            .reduce(into: [:]) { result, element in
                result[element.key] = element.value.sorted(by: { $0.name < $1.name })
            }
    }
    
    var body: some View {
        List(selection: $viewModel.selectedStation) {
            ForEach(Array(groupedStations.keys.sorted()), id: \.self) { country in
                Section(header: Text(country)) {
                    ForEach(groupedStations[country] ?? [], id: \.self) { station in
                        RadioStationRow(station: station, viewModel: viewModel)
                    }
                }
            }
        }
    }
}

struct FavoritesContentView: View {
    @ObservedObject var viewModel: RadioSettingsViewModel
    
    var groupedFavorites: [String: [RadioStation]] {
        Dictionary(grouping: viewModel.favoriteStations) { $0.country }
            .sorted(by: { $0.key < $1.key })
            .reduce(into: [:]) { result, element in
                result[element.key] = element.value.sorted(by: { $0.name < $1.name })
            }
    }
    
    var body: some View {
        Group {
            if viewModel.favoriteStations.isEmpty {
                ContentUnavailableView("No Favorites",
                    systemImage: "heart",
                    description: Text("Add stations to your favorites while browsing")
                )
            } else {
                List(selection: $viewModel.selectedStation) {
                    ForEach(Array(groupedFavorites.keys.sorted()), id: \.self) { country in
                        Section(header: Text(country)) {
                            ForEach(groupedFavorites[country] ?? [], id: \.self) { station in
                                RadioStationRow(station: station, viewModel: viewModel)
                            }
                        }
                    }
                }
            }
        }
    }
}

struct RadioStationRow: View {
    let station: RadioStation
    @ObservedObject var viewModel: RadioSettingsViewModel
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(station.name)
                    .font(.headline)
                Text(station.country)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: {
                viewModel.toggleFavorite(station)
            }) {
                Image(systemName: viewModel.isFavorite(station) ? "heart.fill" : "heart")
                    .foregroundColor(viewModel.isFavorite(station) ? .red : .secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

