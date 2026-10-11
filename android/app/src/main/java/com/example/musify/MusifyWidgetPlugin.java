package com.example.musify;

import android.content.Context;
import android.os.Handler;
import android.os.Looper;

import androidx.annotation.NonNull;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

public class MusifyWidgetPlugin implements FlutterPlugin, MethodChannel.MethodCallHandler {
    private static MethodChannel channel;
    private static final Handler mainHandler = new Handler(Looper.getMainLooper());
    private Context context;

    @Override
    public void onAttachedToEngine(@NonNull FlutterPlugin.FlutterPluginBinding binding) {
        context = binding.getApplicationContext();
        channel = new MethodChannel(binding.getBinaryMessenger(), "com.musify/widget");
        channel.setMethodCallHandler(this);
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPlugin.FlutterPluginBinding binding) {
        if (channel != null) {
            channel.setMethodCallHandler(null);
            channel = null;
        }
        context = null;
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        if ("updateWidget".equals(call.method)) {
            String title = call.argument("title");
            String artist = call.argument("artist");
            String artworkPath = call.argument("artworkPath");
            String artworkUrl = call.argument("artworkUrl");
            Boolean isPlaying = call.argument("isPlaying");
            String source = call.argument("source");

            if (context != null) {
                MusifyWidgetProvider.saveAndBroadcast(
                        context,
                        title != null ? title : "",
                        artist != null ? artist : "",
                        artworkPath,
                        artworkUrl,
                        isPlaying != null && isPlaying,
                        source != null ? source : "My Music"
                );
                result.success(true);
            } else {
                result.error("NO_CONTEXT", "Application context is null", null);
            }
        } else {
            result.notImplemented();
        }
    }

    public static boolean notifyWidgetAction(String action) {
        if (channel != null) {
            mainHandler.post(() -> {
                try {
                    if (channel != null) {
                        channel.invokeMethod("onWidgetAction", action);
                    }
                } catch (Exception ignored) {
                }
            });
            return true;
        }
        return false;
    }
}
