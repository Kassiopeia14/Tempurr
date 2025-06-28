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
    @State private var minDate: Date? = nil
    @State private var maxDate: Date? = nil
    @State private var statusMessage: String? = nil

    var body: some View {
        NavigationView {
            VStack {
                if let minDate, let maxDate {
                    Text("\(minDate.formatted(date: .abbreviated, time: .omitted)) - \(maxDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(.headline)

                    let sortedReadings = readings.sorted { $0.time < $1.time }

                    Chart {
                        ForEach(sortedReadings){
                            reading in
                            LineMark(
                                x: .value("Time", reading.time),
                                y: .value("Temperature", reading.temp)
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(.green)
                        }
                        
                        RuleMark(y: .value("Lower Bound", 2))
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
                                .foregroundStyle(.red.opacity(0.6))

                            // Dashed rule at y = 8
                            RuleMark(y: .value("Upper Bound", 8))
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
                                .foregroundStyle(.red.opacity(0.6))
                        
                    }
                    .chartXScale(domain: minDate...maxDate)
                    .chartXAxis {
                        AxisMarks(values: .automatic) { value in
                            AxisGridLine()
                            AxisTick()
                            AxisValueLabel {
                                if let date = value.as(Date.self) {
                                    Text(date.formatted(.dateTime.hour().minute()))
                                }
                            }
                        }
                    }
                    .frame(height: 200)
                    .padding()
                } else {
                    Text("Loading or no data available")
                        .padding()
                }

                Button("Refresh Data") {
                    Task {
                        await loadData()
                    }
                }
                .padding()
                
                ZStack {
                    if let message = statusMessage {
                        Text(message)
                            .foregroundColor(.green)
                            .font(.caption)
                            .transition(.opacity)
                    }
                }
                .frame(height: 20)
            }
            .navigationTitle("Temperature History")
        }
        .task {
            await loadData()
        }
    }

    private func loadData() async {
        var data = await fetchTemperatureHistory()
        data.sort { $0.time < $1.time }

        await MainActor.run {
            readings = data
            minDate = data.first?.time
            maxDate = data.last?.time
            statusMessage = "Updated"
        }

        // Hide message after delay
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        await MainActor.run {
            statusMessage = nil
        }
    }
}

class InsecureSessionDelegate: NSObject, URLSessionDelegate {
    func urlSession(_ session: URLSession,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        // Always trust the server's certificate (DEV ONLY!)
        if let serverTrust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        } else {
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
}

func fetchTemperatureHistory() async -> [TemperatureHistory] {
    guard let url = URL(string: "http://localhost:6729/history") else {
        print("Invalid URL")
        return []
    }

    let session = URLSession(configuration: .default, delegate: InsecureSessionDelegate(), delegateQueue: nil)

    do {
        let (data, _) = try await session.data(from: url)

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

#Preview {
    ContentView()
}
