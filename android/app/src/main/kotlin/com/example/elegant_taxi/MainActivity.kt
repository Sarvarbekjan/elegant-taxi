package com.example.elegant_taxi

import android.content.Context
import android.media.RingtoneManager
import android.net.Uri
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.yandex.mapkit.MapKitFactory

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.elegant_taxi/native"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        MapKitFactory.setApiKey("f3f7d5ef-8357-44fe-bf9a-c6ca458c7076")
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            val prefs = applicationContext.getSharedPreferences("ElegantTaxiStorage", Context.MODE_PRIVATE)
            when (call.method) {
                "playSound" -> {
                    try {
                        val notification: Uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                        val r = RingtoneManager.getRingtone(applicationContext, notification)
                        r.play()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SOUND_ERR", e.message, null)
                    }
                }
                "saveData" -> {
                    val data = call.argument<String>("data")
                    prefs.edit().putString("app_state_json", data).apply()
                    result.success(true)
                }
                "loadData" -> {
                    val data = prefs.getString("app_state_json", null)
                    result.success(data)
                }
                else -> result.notImplemented()
            }
        }
    }
}
