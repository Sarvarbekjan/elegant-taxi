package com.example.elegant_taxi

import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import com.yandex.mapkit.MapKitFactory

class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        MapKitFactory.setApiKey("f3f7d5ef-8357-44fe-bf9a-c6ca458c7076")
        super.configureFlutterEngine(flutterEngine)
    }
}
