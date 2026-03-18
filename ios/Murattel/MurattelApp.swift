import SwiftUI
import AVFoundation
import Combine

// MARK: - Models
struct Surah: Identifiable, Hashable {
    let id: Int
    let name: String
}

struct Reader: Identifiable, Hashable {
    let id: Int
    let name: String
    let server: String
    let mushafId: Int
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: Reader, rhs: Reader) -> Bool { lhs.id == rhs.id }
}

struct Ayah: Identifiable {
    let id = UUID()
    let verse: Int
    let start: Double
    let end: Double
    let text: String
}

// MARK: - Audio Manager
class AudioManager: ObservableObject {
    private var player: AVPlayer?
    private var timeObserver: Any?
    private var statusObserver: NSKeyValueObservation?

    @Published var isPlaying = false
    @Published var isLoading = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var currentAyah: Ayah?
    @Published var debugStatus: String = ""

    var ayat: [Ayah] = []
    @Published var didFinish: Int = 0

    init() {
        setupAudioSession()
    }

    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
            debugStatus = "Audio session OK"
        } catch {
            debugStatus = "Session error: \(error.localizedDescription)"
        }
    }

    private var downloadTask: URLSessionDataTask?
    private lazy var proxySession: URLSession = {
        let config = URLSessionConfiguration.default
        config.connectionProxyDictionary = [
            "SOCKSEnable": true,
            "SOCKSProxy": "127.0.0.1",
            "SOCKSPort": 10808
        ]
        config.timeoutIntervalForRequest = 30
        return URLSession(configuration: config)
    }()

    func play(surah: Surah, reader: Reader, ayat: [Ayah]) {
        stop()
        self.ayat = ayat
        isLoading = true

        let num = String(format: "%03d", surah.id)
        let urlString = "\(reader.server)\(num).mp3"
        guard let url = URL(string: urlString) else {
            debugStatus = "Invalid URL"
            isLoading = false
            return
        }
        debugStatus = "Downloading..."

        // Try proxy first, fallback to direct
        downloadTask = proxySession.dataTask(with: url) { [weak self] data, response, error in
            if let error = error {
                // Fallback to direct connection
                self?.downloadTask = URLSession.shared.dataTask(with: url) { data, response, error in
                    self?.handleDownload(data: data, error: error, num: num, surah: surah)
                }
                self?.downloadTask?.resume()
                return
            }
            self?.handleDownload(data: data, error: error, num: num, surah: surah)
        }
        downloadTask?.resume()
    }

    private func handleDownload(data: Data?, error: Error?, num: String, surah: Surah) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let error = error {
                self.debugStatus = "Error: \(error.localizedDescription)"
                self.isLoading = false
                return
            }
            guard let data = data, !data.isEmpty else {
                self.debugStatus = "No data received"
                self.isLoading = false
                return
            }

            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("murattel_\(num).mp3")
            do {
                try data.write(to: tempURL)
            } catch {
                self.debugStatus = "File error: \(error.localizedDescription)"
                self.isLoading = false
                return
            }

            self.debugStatus = "Playing \(surah.name)"
            self.playLocalFile(tempURL, surahName: surah.name)
        }
    }

    private func playLocalFile(_ url: URL, surahName: String) {
        let item = AVPlayerItem(url: url)
        let p = AVPlayer(playerItem: item)
        p.volume = 1.0
        self.player = p

        // Observe item status
        statusObserver = item.observe(\.status, options: [.initial, .new]) { [weak self] playerItem, _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch playerItem.status {
                case .readyToPlay:
                    self.debugStatus = "Playing \(surahName)"
                    self.player?.play()
                    self.isPlaying = true
                    self.isLoading = false
                case .failed:
                    let err = playerItem.error?.localizedDescription ?? "unknown"
                    self.debugStatus = "Play error: \(err)"
                    self.isLoading = false
                    self.isPlaying = false
                case .unknown:
                    self.debugStatus = "Preparing..."
                @unknown default:
                    break
                }
            }
        }

        // End of playback
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            self?.isPlaying = false
            self?.debugStatus = "Finished"
            self?.didFinish += 1
        }

        // Time observer
        let interval = CMTime(seconds: 0.3, preferredTimescale: 600)
        timeObserver = p.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            let t = time.seconds
            if t.isFinite && t > 0 {
                self.currentTime = t
            }
            if let d = self.player?.currentItem?.duration.seconds, d.isFinite && d > 0 {
                self.duration = d
            }
            let ms = t * 1000
            self.currentAyah = self.ayat.first(where: { $0.start < ms && $0.end > ms })
        }

        p.play()
    }

    func togglePlayPause() {
        guard let player = player else { return }
        if isPlaying {
            player.pause()
            debugStatus = "Paused"
        } else {
            player.play()
            debugStatus = "Resumed"
        }
        isPlaying.toggle()
    }

    func seek(to time: Double) {
        player?.seek(to: CMTime(seconds: time, preferredTimescale: 600))
    }

    func stop() {
        downloadTask?.cancel()
        downloadTask = nil
        statusObserver?.invalidate()
        statusObserver = nil
        if let obs = timeObserver { player?.removeTimeObserver(obs); timeObserver = nil }
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: player?.currentItem)
        player?.pause()
        player = nil
        isPlaying = false
        isLoading = false
        currentTime = 0
        duration = 0
        currentAyah = nil
        ayat = []
    }
}

// MARK: - API Service
class AyahTimingService {
    private static let proxySession: URLSession = {
        let config = URLSessionConfiguration.default
        config.connectionProxyDictionary = [
            "SOCKSEnable": true,
            "SOCKSProxy": "127.0.0.1",
            "SOCKSPort": 10808
        ]
        config.timeoutIntervalForRequest = 15
        return URLSession(configuration: config)
    }()

    static func fetch(surahId: Int, mushafId: Int) async -> [Ayah] {
        guard surahId >= 1 && surahId <= 114 else { return [] }
        let urlStr = "https://mp3quran.net/api/v3/ayat_timing?surah=\(surahId)&read=\(mushafId)"
        guard let url = URL(string: urlStr) else { return [] }
        do {
            // Try proxy first
            let (data, _) = try await proxySession.data(from: url)
            return parseAyat(data)
        } catch {
            // Fallback to direct
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                return parseAyat(data)
            } catch { return [] }
        }
    }

    private static func parseAyat(_ data: Data) -> [Ayah] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }
        var result: [Ayah] = []
        for item in json {
            guard let ayahNum = item["ayah"] as? Int,
                  let start = item["start_time"] as? Double,
                  let end = item["end_time"] as? Double else { continue }
            let text = item["text"] as? String ?? "الآية \(ayahNum)"
            result.append(Ayah(verse: ayahNum, start: start, end: end, text: text))
        }
        return result
    }
}

// MARK: - App Entry
@main
struct MurattelApp: App {
    var body: some Scene {
        WindowGroup {
            PlayerView()
                .preferredColorScheme(.dark)
        }
    }
}
