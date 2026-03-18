package com.murattel.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Rtl) {
                PlayerScreen()
            }
        }
    }
}

// Theme colors
object Theme {
    val bg = Color(0xFF0B0F14)
    val bgCard = Color(0xFF131920)
    val gold = Color(0xFFC9A94A)
    val goldSoft = Color(0xFFE2C97A)
    val goldDark = Color(0xFF8B7A3A)
    val textMain = Color(0xFFF5F5F5)
    val textMuted = Color(0xFF6B7B8D)
    val border = Color(0xFF1E2A36)
}

@Composable
fun PlayerScreen(vm: AudioViewModel = viewModel()) {
    val context = LocalContext.current
    var currentSurahIndex by remember { mutableIntStateOf(0) }
    var currentReaderIndex by remember { mutableIntStateOf(0) }
    var showSurahDrawer by remember { mutableStateOf(false) }
    var showReaderDrawer by remember { mutableStateOf(false) }
    var isRepeat by remember { mutableStateOf(false) }
    var isShuffle by remember { mutableStateOf(false) }
    var surahFilter by remember { mutableStateOf("") }
    var readerFilter by remember { mutableStateOf("") }

    val currentSurah = QuranData.surahs[currentSurahIndex]
    val currentReader = QuranData.readers[currentReaderIndex]

    fun playSurah(index: Int) {
        currentSurahIndex = index
        val s = QuranData.surahs[index]
        val r = QuranData.readers[currentReaderIndex]
        vm.play(context, s, r)
    }

    fun handleEnded() {
        if (isRepeat) { playSurah(currentSurahIndex); return }
        if (isShuffle) { playSurah((0 until QuranData.surahs.size).random()); return }
        if (currentSurahIndex < QuranData.surahs.size - 1) playSurah(currentSurahIndex + 1)
    }

    // Listen for track end
    val finishCount = vm.didFinish
    LaunchedEffect(finishCount) {
        if (finishCount > 0) handleEnded()
    }

    Box(
        Modifier
            .fillMaxSize()
            .background(Theme.bg)
            .statusBarsPadding()
    ) {
        Column(Modifier.fillMaxSize()) {
            // Top bar
            TopBar(
                onSurahClick = { showSurahDrawer = true },
                onReaderClick = { showReaderDrawer = true }
            )

            // Gold line
            Box(
                Modifier
                    .fillMaxWidth()
                    .height(3.dp)
                    .background(
                        Brush.horizontalGradient(
                            listOf(Color.Transparent, Theme.gold, Theme.goldSoft, Theme.gold, Color.Transparent)
                        )
                    )
            )

            Column(
                Modifier
                    .fillMaxSize()
                    .verticalScroll(rememberScrollState()),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Spacer(Modifier.height(24.dp))

                // Surah name
                Text(
                    "سورة ${currentSurah.name}",
                    color = Theme.goldSoft,
                    fontSize = 28.sp,
                    fontWeight = FontWeight.Bold,
                    textAlign = TextAlign.Center
                )
                Text(
                    currentReader.name,
                    color = Theme.textMuted,
                    fontSize = 14.sp,
                    modifier = Modifier.padding(top = 4.dp)
                )

                Spacer(Modifier.height(24.dp))

                // Medallion
                MedallionView(isPlaying = vm.isPlaying)

                Spacer(Modifier.height(24.dp))

                // Ayah display
                AyahDisplay(ayah = vm.currentAyah)

                Spacer(Modifier.height(16.dp))

                // Progress
                ProgressSection(
                    currentTime = vm.currentTime,
                    duration = vm.duration,
                    onSeek = { vm.seek(it) }
                )

                Spacer(Modifier.height(8.dp))

                // Controls
                ControlsSection(
                    isPlaying = vm.isPlaying,
                    isLoading = vm.isLoading,
                    isRepeat = isRepeat,
                    isShuffle = isShuffle,
                    onPlay = {
                        if (vm.duration == 0f && !vm.isPlaying) playSurah(currentSurahIndex)
                        else vm.togglePlayPause()
                    },
                    onNext = {
                        if (currentSurahIndex < QuranData.surahs.size - 1) playSurah(currentSurahIndex + 1)
                    },
                    onPrev = {
                        if (currentSurahIndex > 0) playSurah(currentSurahIndex - 1)
                    },
                    onRepeat = { isRepeat = !isRepeat; if (isRepeat) isShuffle = false },
                    onShuffle = { isShuffle = !isShuffle; if (isShuffle) isRepeat = false }
                )

                Spacer(Modifier.height(24.dp))

                // Credit
                Text(
                    "\u202Bصُمم بواسطة مصطفى أيوب\u202C",
                    color = Theme.textMuted,
                    fontSize = 12.sp,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.fillMaxWidth()
                )

                Spacer(Modifier.height(30.dp))
            }
        }

        // Drawers
        if (showSurahDrawer) {
            DrawerOverlay { showSurahDrawer = false }
            SurahDrawer(
                filter = surahFilter,
                onFilterChange = { surahFilter = it },
                currentIndex = currentSurahIndex,
                onSelect = { idx ->
                    playSurah(idx)
                    showSurahDrawer = false
                },
                onClose = { showSurahDrawer = false }
            )
        }
        if (showReaderDrawer) {
            DrawerOverlay { showReaderDrawer = false }
            ReaderDrawer(
                filter = readerFilter,
                onFilterChange = { readerFilter = it },
                currentIndex = currentReaderIndex,
                onSelect = { idx ->
                    currentReaderIndex = idx
                    if (vm.isPlaying || vm.duration > 0) playSurah(currentSurahIndex)
                    showReaderDrawer = false
                },
                onClose = { showReaderDrawer = false }
            )
        }
    }
}

@Composable
fun TopBar(onSurahClick: () -> Unit, onReaderClick: () -> Unit) {
    Row(
        Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text("مُرتّل", color = Theme.goldSoft, fontSize = 20.sp, fontWeight = FontWeight.Bold)
        Spacer(Modifier.weight(1f))
        Box(
            Modifier
                .border(1.dp, Theme.border, RoundedCornerShape(20.dp))
                .clickable { onSurahClick() }
                .padding(horizontal = 14.dp, vertical = 6.dp)
        ) {
            Text("القائمة ☰", color = Theme.textMuted, fontSize = 13.sp)
        }
    }
}

@Composable
fun MedallionView(isPlaying: Boolean) {
    val rotation by rememberInfiniteTransition(label = "rot").animateFloat(
        initialValue = 0f,
        targetValue = 360f,
        animationSpec = infiniteRepeatable(
            animation = tween(20000, easing = LinearEasing),
            repeatMode = RepeatMode.Restart
        ),
        label = "rotation"
    )

    Box(
        Modifier
            .size(200.dp)
            .rotate(if (isPlaying) rotation else 0f)
            .clip(CircleShape)
            .background(Theme.bgCard)
            .border(3.dp, Theme.goldDark, CircleShape),
        contentAlignment = Alignment.Center
    ) {
        Text("☽", fontSize = 60.sp, color = Theme.textMain)
    }
}

@Composable
fun AyahDisplay(ayah: Ayah?) {
    Box(
        Modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp)
            .background(Theme.bgCard, RoundedCornerShape(12.dp))
            .border(1.dp, Theme.border, RoundedCornerShape(12.dp))
            .padding(20.dp),
        contentAlignment = Alignment.Center
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text("الآية الحالية", color = Theme.goldSoft, fontSize = 12.sp)
            Spacer(Modifier.height(10.dp))
            Text(
                ayah?.text ?: "--------------------------------------",
                color = if (ayah != null) Theme.textMain else Theme.textMuted,
                fontSize = if (ayah != null) 20.sp else 14.sp,
                textAlign = TextAlign.Center,
                lineHeight = 36.sp
            )
        }
    }
}

@Composable
fun ProgressSection(currentTime: Float, duration: Float, onSeek: (Float) -> Unit) {
    Column(Modifier.padding(horizontal = 20.dp)) {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
            Text(formatTime(currentTime), color = Theme.textMuted, fontSize = 12.sp)
            Text(formatTime(duration), color = Theme.textMuted, fontSize = 12.sp)
        }
        Slider(
            value = if (duration > 0) currentTime / duration else 0f,
            onValueChange = { onSeek(it * duration) },
            colors = SliderDefaults.colors(
                thumbColor = Theme.goldSoft,
                activeTrackColor = Theme.gold,
                inactiveTrackColor = Theme.border
            ),
            modifier = Modifier.fillMaxWidth()
        )
    }
}

@Composable
fun ControlsSection(
    isPlaying: Boolean, isLoading: Boolean, isRepeat: Boolean, isShuffle: Boolean,
    onPlay: () -> Unit, onNext: () -> Unit, onPrev: () -> Unit,
    onRepeat: () -> Unit, onShuffle: () -> Unit
) {
    Row(
        Modifier
            .fillMaxWidth()
            .padding(horizontal = 30.dp),
        horizontalArrangement = Arrangement.SpaceEvenly,
        verticalAlignment = Alignment.CenterVertically
    ) {
        ControlBtn("🔁", isRepeat, onRepeat)
        ControlBtn("⏭", false, onNext)

        // Play button
        Box(
            Modifier
                .size(64.dp)
                .clip(CircleShape)
                .background(Theme.gold)
                .clickable(enabled = !isLoading) { onPlay() },
            contentAlignment = Alignment.Center
        ) {
            if (isLoading) {
                CircularProgressIndicator(color = Theme.bg, strokeWidth = 3.dp, modifier = Modifier.size(28.dp))
            } else {
                Text(
                    if (isPlaying) "⏸" else "▶",
                    fontSize = 24.sp,
                    color = Theme.bg
                )
            }
        }

        ControlBtn("⏮", false, onPrev)
        ControlBtn("🔀", isShuffle, onShuffle)
    }
}

@Composable
fun ControlBtn(icon: String, isActive: Boolean, onClick: () -> Unit) {
    Box(
        Modifier
            .size(44.dp)
            .clip(CircleShape)
            .background(if (isActive) Theme.bgCard else Color.Transparent)
            .border(1.dp, if (isActive) Theme.gold else Theme.border, CircleShape)
            .clickable { onClick() },
        contentAlignment = Alignment.Center
    ) {
        Text(icon, fontSize = 18.sp, color = if (isActive) Theme.gold else Theme.textMuted)
    }
}

@Composable
fun DrawerOverlay(onClick: () -> Unit) {
    Box(
        Modifier
            .fillMaxSize()
            .background(Color.Black.copy(alpha = 0.55f))
            .clickable { onClick() }
    )
}

@Composable
fun SurahDrawer(
    filter: String, onFilterChange: (String) -> Unit,
    currentIndex: Int, onSelect: (Int) -> Unit, onClose: () -> Unit
) {
    val filtered = QuranData.surahs.filterIndexed { _, s -> filter.isEmpty() || s.name.contains(filter) }

    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.CenterEnd) {
        Column(
            Modifier
                .fillMaxHeight()
                .fillMaxWidth(0.75f)
                .background(Theme.bgCard)
                .padding(top = 48.dp)
        ) {
            TextField(
                value = filter,
                onValueChange = onFilterChange,
                placeholder = { Text("ابحث عن سورة...", color = Theme.textMuted) },
                colors = TextFieldDefaults.colors(
                    focusedContainerColor = Theme.bg,
                    unfocusedContainerColor = Theme.bg,
                    focusedTextColor = Theme.textMain,
                    unfocusedTextColor = Theme.textMain,
                    cursorColor = Theme.gold
                ),
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 12.dp, vertical = 8.dp),
                shape = RoundedCornerShape(10.dp),
                singleLine = true
            )

            LazyColumn(Modifier.fillMaxSize()) {
                itemsIndexed(filtered) { _, surah ->
                    val realIdx = QuranData.surahs.indexOfFirst { it.id == surah.id }
                    val isActive = realIdx == currentIndex
                    Row(
                        Modifier
                            .fillMaxWidth()
                            .clickable { onSelect(realIdx) }
                            .background(if (isActive) Theme.gold.copy(alpha = 0.1f) else Color.Transparent)
                            .padding(horizontal = 16.dp, vertical = 14.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            surah.name,
                            color = if (isActive) Theme.gold else Theme.textMain,
                            fontSize = 16.sp,
                            fontWeight = if (isActive) FontWeight.Bold else FontWeight.Normal,
                            modifier = Modifier.weight(1f)
                        )
                        Text(
                            "${surah.id}",
                            color = Theme.textMuted,
                            fontSize = 13.sp
                        )
                        if (isActive) {
                            Spacer(Modifier.width(8.dp))
                            Box(
                                Modifier
                                    .size(8.dp)
                                    .clip(CircleShape)
                                    .background(Theme.gold)
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun ReaderDrawer(
    filter: String, onFilterChange: (String) -> Unit,
    currentIndex: Int, onSelect: (Int) -> Unit, onClose: () -> Unit
) {
    val filtered = QuranData.readers.filterIndexed { _, r -> filter.isEmpty() || r.name.contains(filter) }

    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.CenterStart) {
        Column(
            Modifier
                .fillMaxHeight()
                .fillMaxWidth(0.75f)
                .background(Theme.bgCard)
                .padding(top = 48.dp)
        ) {
            TextField(
                value = filter,
                onValueChange = onFilterChange,
                placeholder = { Text("ابحث عن قارئ...", color = Theme.textMuted) },
                colors = TextFieldDefaults.colors(
                    focusedContainerColor = Theme.bg,
                    unfocusedContainerColor = Theme.bg,
                    focusedTextColor = Theme.textMain,
                    unfocusedTextColor = Theme.textMain,
                    cursorColor = Theme.gold
                ),
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 12.dp, vertical = 8.dp),
                shape = RoundedCornerShape(10.dp),
                singleLine = true
            )

            LazyColumn(Modifier.fillMaxSize()) {
                itemsIndexed(filtered) { _, reader ->
                    val realIdx = QuranData.readers.indexOfFirst { it.id == reader.id }
                    val isActive = realIdx == currentIndex
                    Row(
                        Modifier
                            .fillMaxWidth()
                            .clickable { onSelect(realIdx) }
                            .background(if (isActive) Theme.gold.copy(alpha = 0.1f) else Color.Transparent)
                            .padding(horizontal = 16.dp, vertical = 14.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text("🎙", fontSize = 16.sp)
                        Spacer(Modifier.width(10.dp))
                        Text(
                            reader.name,
                            color = if (isActive) Theme.gold else Theme.textMain,
                            fontSize = 16.sp,
                            fontWeight = if (isActive) FontWeight.Bold else FontWeight.Normal,
                            modifier = Modifier.weight(1f)
                        )
                        if (isActive) {
                            Box(
                                Modifier
                                    .size(8.dp)
                                    .clip(CircleShape)
                                    .background(Theme.gold)
                            )
                        }
                    }
                }
            }
        }
    }
}

fun formatTime(seconds: Float): String {
    if (seconds < 0 || !seconds.isFinite()) return "0:00:00"
    val s = seconds.toInt()
    val h = s / 3600
    val m = (s % 3600) / 60
    val sec = s % 60
    return "$h:${"%02d".format(m)}:${"%02d".format(sec)}"
}
