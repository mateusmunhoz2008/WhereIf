package com.example.autth_injustice_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.app.ActivityManager
import android.content.Context
import android.os.Debug
import android.os.Process
import android.os.SystemClock
import android.os.Build
import android.view.Surface
import android.view.SurfaceView
import android.view.View
import android.view.ViewGroup
import android.webkit.WebView
import java.util.concurrent.Executors
import java.util.concurrent.RejectedExecutionException

class MainActivity : FlutterActivity() {
    private val diagnosticsWorker = Executors.newSingleThreadExecutor()
    private var lastCpu = 0L
    private var lastElapsed = 0L
    private var mapActive = false
    private var originalRefreshRate: Float? = null
    private var originalDisplayModeId: Int? = null

    private fun requestMapRefreshRate(enabled: Boolean) {
        try {
            applyMapRefreshRate(enabled)
        } catch (_: RuntimeException) {
            // Refresh-rate hints are optional on OEM WebView surfaces.
        }
    }

    private fun applyMapRefreshRate(enabled: Boolean) {
        if (!enabled && originalRefreshRate == null) return
        @Suppress("DEPRECATION")
        val currentDisplay = window.decorView.display ?: windowManager.defaultDisplay
        val mode = currentDisplay.mode
        val requestedMode = currentDisplay.supportedModes
            .filter { it.physicalWidth == mode.physicalWidth && it.physicalHeight == mode.physicalHeight }
            .maxByOrNull { it.refreshRate } ?: mode
        val rate = if (enabled) requestedMode.refreshRate else 0f
        val attributes = window.attributes
        if (enabled && originalRefreshRate == null) {
            originalRefreshRate = attributes.preferredRefreshRate
            originalDisplayModeId = attributes.preferredDisplayModeId
        }
        attributes.preferredRefreshRate = if (enabled) rate else originalRefreshRate ?: 0f
        // Some OEMs keep WebView at 60 Hz with only the preferred-rate hint.
        // Select a supported mode at the same resolution, scoped to this page.
        attributes.preferredDisplayModeId = if (enabled) requestedMode.modeId else originalDisplayModeId ?: 0
        window.attributes = attributes
        // WebView and Flutter's surface vote separately on recent Android.
        // A window hint alone can leave Chromium at the normal 60 Hz vote.
        fun updateView(view: View) {
            if (view is WebView || view is SurfaceView) {
                if (Build.VERSION.SDK_INT >= 36) view.requestedFrameRate = rate
                if (Build.VERSION.SDK_INT >= 30 && view is SurfaceView && view.holder.surface.isValid) {
                    view.holder.surface.setFrameRate(rate, Surface.FRAME_RATE_COMPATIBILITY_DEFAULT)
                }
            }
            if (view is ViewGroup) for (index in 0 until view.childCount) updateView(view.getChildAt(index))
        }
        updateView(window.decorView)
        if (!enabled) {
            originalRefreshRate = null
            originalDisplayModeId = null
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "whereif/map_runtime")
            .setMethodCallHandler { call, result ->
                if (call.method != "setActive") {
                    result.notImplemented()
                } else {
                    mapActive = call.argument<Boolean>("active") == true
                    requestMapRefreshRate(mapActive)
                    result.success(null)
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "whereif/map_diagnostics")
            .setMethodCallHandler { call, result ->
                if (call.method != "sample") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                // Reading PSS can be slow: never collect it on Android's UI thread.
                try {
                    diagnosticsWorker.execute {
                        try {
                            val elapsed = SystemClock.elapsedRealtime()
                            val cpu = Process.getElapsedCpuTime()
                            val cores = Runtime.getRuntime().availableProcessors().coerceAtLeast(1)
                            val cpuPercent = if (lastElapsed > 0 && elapsed > lastElapsed)
                                (cpu - lastCpu).toDouble() * 100 / (elapsed - lastElapsed) / cores
                                else null
                            lastCpu = cpu
                            lastElapsed = elapsed
                            val memory = Debug.MemoryInfo()
                            Debug.getMemoryInfo(memory)
                            val device = ActivityManager.MemoryInfo()
                            (getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager).getMemoryInfo(device)
                            val sample = mapOf(
                                "cpuPercent" to cpuPercent,
                                "cores" to cores,
                                "appMemoryMb" to memory.totalPss / 1024.0,
                                "graphicsMemoryMb" to memory.getMemoryStat("summary.graphics")?.toDoubleOrNull()?.div(1024),
                                "availableMemoryMb" to device.availMem / 1048576.0,
                                "lowMemory" to device.lowMemory,
                                "memoryThresholdMb" to device.threshold / 1048576.0
                            )
                            runOnUiThread { result.success(sample) }
                        } catch (error: Exception) {
                            runOnUiThread { result.error("diagnostics", error.message, null) }
                        }
                    }
                } catch (_: RejectedExecutionException) {
                    result.error("diagnostics_unavailable", "Activity is closing.", null)
                }
            }
    }

    override fun onDestroy() {
        requestMapRefreshRate(false)
        diagnosticsWorker.shutdown()
        super.onDestroy()
    }

    override fun onPause() {
        requestMapRefreshRate(false)
        super.onPause()
    }

    override fun onResume() {
        super.onResume()
        if (mapActive) requestMapRefreshRate(true)
    }
}
