import SwiftUI

// MARK: - Theme Colors (matching website CSS exactly)
struct Theme {
    static let bg = Color(red: 0.043, green: 0.059, blue: 0.078)           // #0b0f14
    static let surface = Color(red: 0.075, green: 0.098, blue: 0.125)      // #131920
    static let surface2 = Color(red: 0.102, green: 0.133, blue: 0.188)     // #1a2230
    static let border = Color(red: 0.706, green: 0.569, blue: 0.314).opacity(0.18)
    static let gold = Color(red: 0.788, green: 0.663, blue: 0.290)         // #c9a94a
    static let goldSoft = Color(red: 0.886, green: 0.788, blue: 0.478)     // #e2c97a
    static let goldDim = Color(red: 0.788, green: 0.663, blue: 0.290).opacity(0.15)
    static let text = Color(red: 0.941, green: 0.902, blue: 0.800)         // #f0e6cc
    static let textMuted = Color(red: 0.541, green: 0.502, blue: 0.439)    // #8a8070
}

// MARK: - Main Player View
struct PlayerView: View {
    @StateObject private var audio = AudioManager()
    @State private var currentSurahIndex = 0
    @State private var currentReaderIndex = 0
    @State private var isRepeat = false
    @State private var isShuffle = false
    @State private var showSurahDrawer = false
    @State private var showReaderDrawer = false
    @State private var surahFilter = ""
    @State private var readerFilter = ""
    @State private var showMenu = false

    private var currentSurah: Surah { QuranData.surahs[currentSurahIndex] }
    private var currentReader: Reader { QuranData.readers[currentReaderIndex] }

    private var filteredSurahs: [Surah] {
        if surahFilter.isEmpty { return QuranData.surahs }
        return QuranData.surahs.filter { $0.name.contains(surahFilter) }
    }
    private var filteredReaders: [Reader] {
        if readerFilter.isEmpty { return QuranData.readers }
        return QuranData.readers.filter { $0.name.contains(readerFilter) }
    }

    var body: some View {
        ZStack {
            // Background
            Theme.bg.ignoresSafeArea()

            // Radial gradient overlay (matching website)
            RadialGradient(colors: [Theme.gold.opacity(0.07), .clear], center: .top, startRadius: 0, endRadius: 400)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Mobile top bar
                mobileBar

                // Gold top line
                Rectangle()
                    .fill(LinearGradient(colors: [.clear, Theme.gold, Theme.goldSoft, Theme.gold, .clear], startPoint: .leading, endPoint: .trailing))
                    .frame(height: 3)
                    .opacity(0.6)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Now Playing
                        nowPlayingSection

                        // Medallion
                        medallionSection

                        // Ayah display
                        ayahSection

                        // Progress
                        progressSection

                        // Controls
                        controlsSection

                        // Credit
                        Text("صُمم بواسطة مصطفى أيوب")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.textMuted)
                            .padding(.top, 30)
                            .padding(.bottom, 20)

                    }
                }
            }

            // Overlay
            if showSurahDrawer || showReaderDrawer {
                Color.black.opacity(0.55)
                    .ignoresSafeArea()
                    .onTapGesture {
                        showSurahDrawer = false
                        showReaderDrawer = false
                    }
            }

            // Surah Drawer
            drawerView(isOpen: $showSurahDrawer, fromLeading: true) {
                drawerContent(
                    icon: "📖",
                    title: "السور",
                    filter: $surahFilter,
                    placeholder: "ابحث عن سورة..."
                ) {
                    ForEach(filteredSurahs) { s in
                        let isActive = s.id == currentSurah.id
                        listItem(num: "\(s.id)", name: s.name, isActive: isActive) {
                            selectSurah(QuranData.surahs.firstIndex(where: { $0.id == s.id }) ?? 0)
                            showSurahDrawer = false
                        }
                    }
                }
            }

            // Reader Drawer
            drawerView(isOpen: $showReaderDrawer, fromLeading: false) {
                drawerContent(
                    icon: "🎙",
                    title: "القراء",
                    filter: $readerFilter,
                    placeholder: "ابحث عن قارئ..."
                ) {
                    ForEach(Array(filteredReaders.enumerated()), id: \.element.id) { idx, r in
                        let isActive = r.id == currentReader.id
                        listItem(num: "\(idx + 1)", name: r.name, isActive: isActive) {
                            selectReader(QuranData.readers.firstIndex(where: { $0.id == r.id }) ?? 0)
                            showReaderDrawer = false
                        }
                    }
                }
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .onAppear {}
        .onChange(of: audio.didFinish) { _ in
            handleEnded()
        }
    }

    // MARK: - Mobile Top Bar
    private var mobileBar: some View {
        HStack {
            Text("مُرتّل")
                .font(.system(size: 20, weight: .bold, design: .serif))
                .foregroundColor(Theme.goldSoft)

            Spacer()

            // Menu button
            Menu {
                Button(action: { showSurahDrawer = true }) {
                    Label("السور", systemImage: "book")
                }
                Button(action: { showReaderDrawer = true }) {
                    Label("القراء", systemImage: "mic")
                }
            } label: {
                HStack(spacing: 6) {
                    VStack(spacing: 3) {
                        ForEach(0..<3, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(Theme.textMuted)
                                .frame(width: 14, height: 1.5)
                        }
                    }
                    Text("القائمة")
                        .font(.system(size: 13))
                        .foregroundColor(Theme.textMuted)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Theme.surface2)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border, lineWidth: 1))
                .cornerRadius(8)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(Theme.surface)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.border).frame(height: 1)
        }
    }

    // MARK: - Now Playing
    private var nowPlayingSection: some View {
        VStack(spacing: 4) {
            Text(currentSurahIndex >= 0 ? "سورة \(currentSurah.name)" : "اختر سورة")
                .font(.system(size: 28, weight: .bold, design: .serif))
                .foregroundColor(Theme.goldSoft)

            Text(currentReader.name)
                .font(.system(size: 13))
                .foregroundColor(Theme.textMuted)
        }
        .padding(.top, 30)
        .padding(.bottom, 20)
    }

    // MARK: - Medallion (rotating crescent moon)
    private var medallionSection: some View {
        ZStack {
            // Dashed outer ring
            Circle()
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .foregroundColor(Theme.gold.opacity(0.2))
                .frame(width: 170, height: 170)

            // Outer glow
            Circle()
                .fill(Theme.gold.opacity(0.06))
                .frame(width: 160, height: 160)

            // Main circle
            Circle()
                .fill(
                    RadialGradient(colors: [Theme.surface2, Theme.surface], center: .init(x: 0.35, y: 0.3), startRadius: 0, endRadius: 80)
                )
                .frame(width: 140, height: 140)
                .overlay(Circle().stroke(Theme.border, lineWidth: 2))
                .shadow(color: .black.opacity(0.4), radius: 16, y: 8)
                .shadow(color: Theme.gold.opacity(0.1), radius: 20)

            // Crescent moon
            Text("☽")
                .font(.system(size: 56))
                .rotationEffect(.degrees(audio.isPlaying ? 360 : 0))
                .animation(audio.isPlaying ? .linear(duration: 20).repeatForever(autoreverses: false) : .default, value: audio.isPlaying)
        }
        .padding(.vertical, 10)
    }

    // MARK: - Ayah Section
    private var ayahSection: some View {
        VStack(spacing: 0) {
            // Ayah box
            VStack(spacing: 14) {
                Text("الآية الحالية")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.gold)
                    .tracking(1)
                    .opacity(0.8)

                if let ayah = audio.currentAyah {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(ayah.text)
                            .font(.system(size: 22, design: .serif))
                            .foregroundColor(Theme.text)
                            .multilineTextAlignment(.center)
                            .lineSpacing(8)

                        // Ayah number badge
                        Text(toArabicDigits(ayah.verse))
                            .font(.system(size: 12))
                            .foregroundColor(Theme.gold)
                            .frame(width: 26, height: 26)
                            .background(Theme.goldDim)
                            .clipShape(Circle())
                    }
                } else if !audio.ayat.isEmpty {
                    Text("بِسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ")
                        .font(.system(size: 22, design: .serif))
                        .foregroundColor(Theme.text)
                        .multilineTextAlignment(.center)
                        .lineSpacing(8)
                } else {
                    Text("------------------------------")
                        .font(.system(size: 18))
                        .foregroundColor(Theme.textMuted)
                }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 28)
            .frame(maxWidth: .infinity)
            .background(Theme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1)
            )
            .overlay(alignment: .top) {
                // Gold line at top of ayah box
                LinearGradient(colors: [.clear, Theme.gold, .clear], startPoint: .leading, endPoint: .trailing)
                    .frame(height: 1)
                    .padding(.horizontal, 60)
            }
            .cornerRadius(14)
            .shadow(color: .black.opacity(0.25), radius: 15)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
    }

    // MARK: - Progress Section
    private var progressSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text(formatTime(audio.currentTime))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(Theme.textMuted)
                Spacer()
                Text(formatTime(audio.duration))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(Theme.textMuted)
            }

            // Progress slider
            Slider(
                value: Binding(
                    get: { audio.currentTime },
                    set: { audio.seek(to: $0) }
                ),
                in: 0...max(audio.duration, 1)
            )
            .accentColor(Theme.gold)
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Controls
    private var controlsSection: some View {
        HStack(spacing: 14) {
            // Shuffle button
            controlButton(size: 42, isSmall: true) {
                toggleShuffle()
            } label: {
                Image(systemName: "shuffle")
                    .font(.system(size: 14))
                    .foregroundColor(isShuffle ? Theme.gold : Theme.textMuted)
            }

            // Previous
            controlButton(size: 52, isSmall: false) {
                prevSurah()
            } label: {
                Image(systemName: "backward.end.fill")
                    .font(.system(size: 16))
                    .foregroundColor(Theme.textMuted)
            }
            .disabled(currentSurahIndex == 0)

            // Play/Pause (gold)
            Button(action: togglePlay) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [Theme.gold, Color(red: 0.627, green: 0.486, blue: 0.157)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 64, height: 64)
                        .shadow(color: Theme.gold.opacity(0.35), radius: 10)

                    if audio.isLoading {
                        ProgressView()
                            .tint(Theme.bg)
                    } else {
                        Image(systemName: audio.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 22))
                            .foregroundColor(Theme.bg)
                    }
                }
            }
            .disabled(audio.isLoading)

            // Next
            controlButton(size: 52, isSmall: false) {
                nextSurah()
            } label: {
                Image(systemName: "forward.end.fill")
                    .font(.system(size: 16))
                    .foregroundColor(Theme.textMuted)
            }
            .disabled(currentSurahIndex >= QuranData.surahs.count - 1)

            // Repeat
            controlButton(size: 42, isSmall: true) {
                toggleRepeat()
            } label: {
                Image(systemName: "repeat")
                    .font(.system(size: 14))
                    .foregroundColor(isRepeat ? Theme.gold : Theme.textMuted)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
    }

    // MARK: - Helper: Control Button
    private func controlButton<Label: View>(size: CGFloat, isSmall: Bool, action: @escaping () -> Void, @ViewBuilder label: () -> Label) -> some View {
        Button(action: action) {
            label()
                .frame(width: size, height: size)
                .background(Theme.surface)
                .overlay(Circle().stroke(Theme.border, lineWidth: 1))
                .clipShape(Circle())
        }
    }

    // MARK: - Drawer View
    private func drawerView<Content: View>(isOpen: Binding<Bool>, fromLeading: Bool, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            if !fromLeading { Spacer() }
            content()
                .frame(width: 280)
                .background(Theme.surface)
                .offset(x: isOpen.wrappedValue ? 0 : (fromLeading ? -300 : 300))
                .animation(.easeInOut(duration: 0.3), value: isOpen.wrappedValue)
            if fromLeading { Spacer() }
        }
        .ignoresSafeArea()
    }

    // MARK: - Drawer Content
    private func drawerContent<Content: View>(icon: String, title: String, filter: Binding<String>, placeholder: String, @ViewBuilder list: () -> Content) -> some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 10) {
                Text(icon)
                    .font(.system(size: 14))
                    .frame(width: 30, height: 30)
                    .background(Theme.goldDim)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border, lineWidth: 1))
                    .cornerRadius(8)

                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.goldSoft)
                    .tracking(0.3)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.horizontal, 18)
            .padding(.top, 22)
            .padding(.bottom, 14)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Theme.border).frame(height: 1)
            }

            // Search
            HStack {
                TextField(placeholder, text: filter)
                    .font(.system(size: 13))
                    .foregroundColor(Theme.text)
                    .multilineTextAlignment(.trailing)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Theme.surface2)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border, lineWidth: 1))
                    .cornerRadius(8)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Theme.border).frame(height: 1)
            }

            // List
            ScrollView {
                LazyVStack(spacing: 0) {
                    list()
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 8)
            }
        }
    }

    // MARK: - List Item
    private func listItem(num: String, name: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(num)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(isActive ? Theme.gold : Theme.textMuted)
                    .frame(width: 22)

                Text(name)
                    .font(.system(size: 13.5))
                    .foregroundColor(isActive ? Theme.goldSoft : Theme.text)

                Spacer()

                Circle()
                    .fill(Theme.gold)
                    .frame(width: 6, height: 6)
                    .opacity(isActive ? 1 : 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(isActive ? Theme.goldDim : .clear)
            .cornerRadius(9)
        }
    }

    // MARK: - Actions
    private func playSurah(_ index: Int) {
        currentSurahIndex = index
        let s = QuranData.surahs[index]
        let r = QuranData.readers[currentReaderIndex]

        // Start audio immediately, fetch ayat timing in background
        audio.play(surah: s, reader: r, ayat: [])

        Task {
            let ayat = await AyahTimingService.fetch(surahId: s.id, mushafId: r.mushafId)
            await MainActor.run {
                audio.ayat = ayat
            }
        }
    }

    private func selectSurah(_ index: Int) {
        guard !audio.isLoading else { return }
        playSurah(index)
    }

    private func selectReader(_ index: Int) {
        currentReaderIndex = index
        selectSurah(currentSurahIndex)
    }

    private func togglePlay() {
        if audio.duration == 0 && !audio.isPlaying {
            playSurah(currentSurahIndex)
        } else {
            audio.togglePlayPause()
        }
    }

    private func prevSurah() {
        guard currentSurahIndex > 0 else { return }
        selectSurah(currentSurahIndex - 1)
    }

    private func nextSurah() {
        guard currentSurahIndex < QuranData.surahs.count - 1 else { return }
        selectSurah(currentSurahIndex + 1)
    }

    private func toggleShuffle() {
        isShuffle.toggle()
        if isShuffle { isRepeat = false }
    }

    private func toggleRepeat() {
        isRepeat.toggle()
        if isRepeat { isShuffle = false }
    }

    private func handleEnded() {
        if isRepeat {
            playSurah(currentSurahIndex)
            return
        }
        if isShuffle {
            let random = Int.random(in: 0..<QuranData.surahs.count)
            selectSurah(random)
            return
        }
        if currentSurahIndex < QuranData.surahs.count - 1 {
            selectSurah(currentSurahIndex + 1)
        }
    }

    // MARK: - Helpers
    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00:00" }
        let s = Int(seconds)
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        return "\(h):\(String(format: "%02d", m)):\(String(format: "%02d", sec))"
    }

    private func toArabicDigits(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "ar_EG")
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
}
