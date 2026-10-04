package com.example.musify;

import androidx.annotation.NonNull;

import com.ryanheise.audioservice.AudioServiceActivity;
import io.flutter.embedding.engine.FlutterEngine;

public class MainActivity extends AudioServiceActivity {
    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        flutterEngine.getPlugins().add(new MediaStorePlugin());
        flutterEngine.getPlugins().add(new RingtonePlugin());
        flutterEngine.getPlugins().add(new MusifyWidgetPlugin());
    }
}

