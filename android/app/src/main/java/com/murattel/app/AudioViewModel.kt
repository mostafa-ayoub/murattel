package com.murattel.app

import android.content.Context
import android.net.Uri
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import androidx.media3.common.MediaItem
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.net.InetSocketAddress
import java.net.Proxy
import java.net.URL
import java.io.File
import okhttp3.OkHttpClient
import okhttp3.Request

class AudioViewModel : ViewModel() {
    private var player: ExoPlayer? = null

    var isPlaying by mutableStateOf(false)
    var isLoading by mutableStateOf(false)
    var currentTime by mutableFloatStateOf(0f)
    var duration by mutableFloatStateOf(0f)
    var currentAyah by mutableStateOf<Ayah?>(null)
    var didFinish by mutableIntStateOf(0)

    var ayat: List<Ayah> = emptyList()

    private val proxyClient = OkHttpClient.Builder()
        .proxy(Proxy(Proxy.Type.SOCKS, InetSocketAddress("127.0.0.1", 10808)))
        .build()
    private val directClient = OkHttpClient()

    fun play(context: Context, surah: Surah, reader: Reader) {
        stop()
        isLoading = true
        val num = String.format("%03d", surah.id)
        val urlString = "${reader.server}${num}.mp3"

        viewModelScope.launch {
            val localFile = downloadAudio(context, urlString, num)
            if (localFile != null) {
                withContext(Dispatchers.Main) {
                    playLocalFile(context, localFile, surah.name)
                }
            } else {
                isLoading = false
            }

            // Fetch ayat timing in background
            val fetchedAyat = fetchAyatTiming(surah.id, reader.mushafId)
            ayat = fetchedAyat
        }
    }

    private suspend fun downloadAudio(context: Context, url: String, num: String): File? {
        return withContext(Dispatchers.IO) {
            val tempFile = File(context.cacheDir, "murattel_$num.mp3")
            try {
                // Try proxy first
                val request = Request.Builder().url(url).build()
                val response = try {
                    proxyClient.newCall(request).execute()
                } catch (e: Exception) {
                    directClient.newCall(request).execute()
                }
                response.body?.byteStream()?.use { input ->
                    tempFile.outputStream().use { output ->
                        input.copyTo(output)
                    }
                }
                tempFile
            } catch (e: Exception) {
                null
            }
        }
    }

    private fun playLocalFile(context: Context, file: File, surahName: String) {
        val p = ExoPlayer.Builder(context).build()
        player = p

        p.addListener(object : Player.Listener {
            override fun onPlaybackStateChanged(state: Int) {
                when (state) {
                    Player.STATE_READY -> {
                        isLoading = false
                        isPlaying = true
                        duration = (p.duration / 1000f)
                    }
                    Player.STATE_ENDED -> {
                        isPlaying = false
                        didFinish++
                    }
                }
            }
        })

        val mediaItem = MediaItem.fromUri(Uri.fromFile(file))
        p.setMediaItem(mediaItem)
        p.prepare()
        p.play()

        // Time observer
        viewModelScope.launch {
            while (true) {
                delay(300)
                val pl = player ?: break
                if (pl.isPlaying) {
                    val t = pl.currentPosition / 1000f
                    currentTime = t
                    val ms = t * 1000.0
                    currentAyah = ayat.firstOrNull { it.start < ms && it.end > ms }
                }
            }
        }
    }

    fun togglePlayPause() {
        val p = player ?: return
        if (isPlaying) {
            p.pause()
        } else {
            p.play()
        }
        isPlaying = !isPlaying
    }

    fun seek(time: Float) {
        player?.seekTo((time * 1000).toLong())
    }

    fun stop() {
        player?.stop()
        player?.release()
        player = null
        isPlaying = false
        isLoading = false
        currentTime = 0f
        duration = 0f
        currentAyah = null
        ayat = emptyList()
    }

    private suspend fun fetchAyatTiming(surahId: Int, mushafId: Int): List<Ayah> {
        return withContext(Dispatchers.IO) {
            try {
                val url = "https://mp3quran.net/api/v3/ayat_timing?surah=$surahId&read=$mushafId"
                val request = Request.Builder().url(url).build()
                val response = try {
                    proxyClient.newCall(request).execute()
                } catch (e: Exception) {
                    directClient.newCall(request).execute()
                }
                val json = response.body?.string() ?: return@withContext emptyList()
                val type = object : TypeToken<List<Map<String, Any>>>() {}.type
                val list: List<Map<String, Any>> = Gson().fromJson(json, type)
                list.mapNotNull { item ->
                    val ayahNum = (item["ayah"] as? Double)?.toInt() ?: return@mapNotNull null
                    val start = item["start_time"] as? Double ?: return@mapNotNull null
                    val end = item["end_time"] as? Double ?: return@mapNotNull null
                    val text = item["text"] as? String ?: "الآية $ayahNum"
                    Ayah(ayahNum, start, end, text)
                }
            } catch (e: Exception) {
                emptyList()
            }
        }
    }

    override fun onCleared() {
        super.onCleared()
        stop()
    }
}
