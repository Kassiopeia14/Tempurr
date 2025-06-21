//
//  ContentView.swift
//  Tempurr
//
//  Created by Kassiopeia on 21/06/2025.
//

import SwiftUI
import Charts

struct TemperatureHistory: Codable, Identifiable {
    let id = UUID()
    let temp: Double
    let time: Date

    enum CodingKeys: String, CodingKey {
        case temp
        case time = "created_at"
    }
}

struct ContentView: View {
    @State private var readings: [TemperatureHistory] = []

    var minDate: Date? {
            readings.map { $0.time }.min()
        }

        var maxDate: Date? {
            readings.map { $0.time }.max()
        }
    
    var body: some View {
        NavigationView {
            VStack{
            if let minDate, let maxDate {
                 
                        Text("minDate: \(minDate.formatted(date: .abbreviated, time: .shortened))")
                        Text("maxDate: \(maxDate.formatted(date: .abbreviated, time: .shortened))")
                            .font(.headline)
                    
                
                                Chart(readings) { reading in
                                    LineMark(
                                        x: .value("Time", reading.time),
                                        y: .value("Temperature", reading.temp)
                                    )
                                    .interpolationMethod(.catmullRom)
                                    .foregroundStyle(.blue)
                                }
                                .chartXScale(domain: minDate...maxDate)
                                .frame(height: 200)
                                .padding()
                
                //            List(readings) { reading in
                //                VStack(alignment: .leading) {
                //                    Text("Time: \(reading.time.formatted(date: .abbreviated, time: .shortened))")
                //                    Text("Temp: \(reading.temp, specifier: "%.1f") °C")
                //                        .font(.headline)
                //                }
                //            }
                //            .navigationTitle("Temperature History")
            }
            }
        }
        .task {
            readings = await fetchTemperatureHistory()
        }
    }
}

func fetchTemperatureHistory() async -> [TemperatureHistory] {
    guard let url = URL(string: "http://localhost:6729/history") else {
        print("Invalid URL")
        return []
    }

    do {
        let (data, _) = try await URLSession.shared.data(from: url)

        print("📦 RAW JSON:")
        print(String(data: data, encoding: .utf8) ?? "Unable to convert to string")
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateStr = try container.decode(String.self)
            
            let trimmed = dateStr.replacingOccurrences(of: #"(\.\d{3})"#, with: "", options: .regularExpression)

            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]

            guard let date = formatter.date(from: trimmed) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Invalid ISO8601 date: \(dateStr)"
                )
            }

            return date
        }

        return try decoder.decode([TemperatureHistory].self, from: data)
    } catch {
        print("Error fetching or decoding: \(error)")
        return []
    }
}
