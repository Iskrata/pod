//
//  RadioSettings.swift
//  Pod
//

import SwiftUI
import Combine

// MARK: - Model

struct RadioStation: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let url: String
    let country: String

    enum CodingKeys: String, CodingKey {
        case id = "stationuuid"
        case name, url, country
    }
}

// MARK: - ViewModel

class RadioSettingsViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var searchResults: [RadioStation] = []
    @Published var favoriteStations: [RadioStation] = []
    @Published var isSearching = false
    @Published var errorMessage: String?
    @Published var suggestedStations: [RadioStation] = []

    private var cancellables = Set<AnyCancellable>()
    private let baseURL = "https://de1.api.radio-browser.info/json/stations"

    init() {
        loadFavorites()
        loadSuggestedStations()
        setupSearch()
    }

    private func setupSearch() {
        $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] text in
                text.isEmpty ? (self?.searchResults = []) : self?.searchStations()
            }
            .store(in: &cancellables)
    }

    func searchStations() {
        guard !searchText.isEmpty else { return }
        isSearching = true
        errorMessage = nil

        var components = URLComponents(string: "\(baseURL)/search")!
        components.queryItems = [URLQueryItem(name: "name", value: searchText)]

        guard let url = components.url else {
            errorMessage = "Invalid search"
            isSearching = false
            return
        }

        fetchStations(from: url) { [weak self] stations in
            self?.searchResults = stations ?? []
            self?.isSearching = false
        }
    }

    func loadSuggestedStations() {
        guard let url = URL(string: "\(baseURL)/topclick/10") else { return }
        fetchStations(from: url) { [weak self] stations in
            self?.suggestedStations = stations ?? []
        }
    }

    private func fetchStations(from url: URL, completion: @escaping ([RadioStation]?) -> Void) {
        URLSession.shared.dataTask(with: url) { data, _, error in
            DispatchQueue.main.async {
                if error != nil { completion(nil); return }
                guard let data = data,
                      let stations = try? JSONDecoder().decode([RadioStation].self, from: data)
                else { completion(nil); return }
                completion(stations)
            }
        }.resume()
    }

    func toggleFavorite(_ station: RadioStation) {
        if favoriteStations.contains(where: { $0.id == station.id }) {
            favoriteStations.removeAll { $0.id == station.id }
        } else {
            favoriteStations.append(station)
        }
        saveFavorites()
    }

    func isFavorite(_ station: RadioStation) -> Bool {
        favoriteStations.contains { $0.id == station.id }
    }

    private func saveFavorites() {
        guard let data = try? JSONEncoder().encode(favoriteStations) else { return }
        UserDefaults.standard.set(data, forKey: "favoriteStations")
        NotificationCenter.default.post(name: NSNotification.Name("FavoriteStationsChanged"), object: nil)
    }

    private func loadFavorites() {
        guard let data = UserDefaults.standard.data(forKey: "favoriteStations"),
              let stations = try? JSONDecoder().decode([RadioStation].self, from: data)
        else { return }
        favoriteStations = stations
    }
}

// MARK: - Main View

struct RadioSettings: View {
    @StateObject private var viewModel = RadioSettingsViewModel()
    @State private var selectedSection = "search"

    var body: some View {
        HSplitView {
            VStack(alignment: .leading, spacing: 0) {
                SidebarButton(title: "Search", icon: "magnifyingglass", isSelected: selectedSection == "search") {
                    selectedSection = "search"
                }
                SidebarButton(title: "Favorites", icon: "heart.fill", isSelected: selectedSection == "favorites") {
                    selectedSection = "favorites"
                }
                Spacer()
            }
            .frame(minWidth: 140, maxWidth: 180)
            .background(Color(NSColor.controlBackgroundColor))

            Group {
                switch selectedSection {
                case "favorites":
                    RadioFavoritesView(viewModel: viewModel)
                default:
                    RadioSearchView(viewModel: viewModel)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Search View

struct RadioSearchView: View {
    @ObservedObject var viewModel: RadioSettingsViewModel

    var body: some View {
        VStack(spacing: 0) {
            SettingsSearchField(text: $viewModel.searchText, placeholder: "Search radio stations")
                .padding(16)

            Divider()

            if viewModel.isSearching {
                SettingsEmptyState(icon: "arrow.clockwise", title: "Searching...", description: "")
            } else if let error = viewModel.errorMessage {
                SettingsEmptyState(icon: "exclamationmark.triangle", title: "Error", description: error)
            } else if !viewModel.searchText.isEmpty {
                RadioStationsList(stations: viewModel.searchResults, viewModel: viewModel)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Popular Stations")
                        .font(.headline)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    RadioStationsList(stations: viewModel.suggestedStations, viewModel: viewModel)
                }
            }
        }
    }
}

// MARK: - Favorites View

struct RadioFavoritesView: View {
    @ObservedObject var viewModel: RadioSettingsViewModel

    var body: some View {
        if viewModel.favoriteStations.isEmpty {
            SettingsEmptyState(
                icon: "heart",
                title: "No Favorites",
                description: "Add stations to favorites while browsing"
            )
        } else {
            RadioStationsList(stations: viewModel.favoriteStations, viewModel: viewModel)
        }
    }
}

// MARK: - Stations List

struct RadioStationsList: View {
    let stations: [RadioStation]
    @ObservedObject var viewModel: RadioSettingsViewModel

    private var grouped: [(country: String, stations: [RadioStation])] {
        Dictionary(grouping: stations) { $0.country }
            .map { (country: $0.key, stations: $0.value.sorted { $0.name < $1.name }) }
            .sorted { $0.country < $1.country }
    }

    var body: some View {
        List {
            ForEach(grouped, id: \.country) { group in
                Section(header: Text(group.country)) {
                    ForEach(group.stations) { station in
                        RadioStationRow(station: station, viewModel: viewModel)
                    }
                }
            }
        }
    }
}

// MARK: - Station Row

struct RadioStationRow: View {
    let station: RadioStation
    @ObservedObject var viewModel: RadioSettingsViewModel

    private var isFavorite: Bool { viewModel.isFavorite(station) }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(station.name)
                    .font(.headline)
                    .lineLimit(1)
                Text(station.country)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: { viewModel.toggleFavorite(station) }) {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .font(.title3)
                    .foregroundColor(isFavorite ? .red : .secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}
