package com.example.musify;

import android.content.ContentResolver;
import android.database.Cursor;
import android.net.Uri;
import android.provider.MediaStore;

import androidx.annotation.NonNull;

import java.util.HashMap;
import java.util.Map;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

/**
 * Platform channel plugin that queries Android MediaStore for audio metadata.
 * MediaStore uses Android's built-in media scanner which reads ID3, Vorbis comments,
 * MP4 atoms, etc. more reliably than manual binary parsing.
 */
public class MediaStorePlugin implements FlutterPlugin, MethodChannel.MethodCallHandler {
    private MethodChannel channel;
    private ContentResolver contentResolver;

    @Override
    public void onAttachedToEngine(@NonNull FlutterPlugin.FlutterPluginBinding binding) {
        channel = new MethodChannel(binding.getBinaryMessenger(), "com.musify/mediastore");
        channel.setMethodCallHandler(this);
        contentResolver = binding.getApplicationContext().getContentResolver();
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPlugin.FlutterPluginBinding binding) {
        if (channel != null) {
            channel.setMethodCallHandler(null);
            channel = null;
        }
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        if ("getMetadata".equals(call.method)) {
            String filePath = call.argument("filePath");
            if (filePath == null || filePath.isEmpty()) {
                result.error("INVALID_ARG", "filePath is required", null);
                return;
            }
            Map<String, Object> metadata = queryMediaStore(filePath);
            result.success(metadata);
        } else {
            result.notImplemented();
        }
    }

    private Map<String, Object> queryMediaStore(String filePath) {
        Map<String, Object> metadata = new HashMap<>();

        // Normalise path for DATA column comparison
        String normalizedPath = filePath;
        if (normalizedPath.startsWith("file://")) {
            normalizedPath = normalizedPath.substring(7);
        }

        String[] projection = {
                MediaStore.Audio.Media.TITLE,
                MediaStore.Audio.Media.ARTIST,
                MediaStore.Audio.Media.ALBUM,
                MediaStore.Audio.Media.DURATION,
                MediaStore.Audio.Media.TRACK,
        };

        String selection = MediaStore.Audio.Media.DATA + "=?";
        String[] selectionArgs = {normalizedPath};

        Uri uri = MediaStore.Audio.Media.EXTERNAL_CONTENT_URI;
        Cursor cursor = null;
        try {
            cursor = contentResolver.query(uri, projection, selection, selectionArgs, null);
            if (cursor != null && cursor.moveToFirst()) {
                String title = getStringColumn(cursor, MediaStore.Audio.Media.TITLE);
                String artist = getStringColumn(cursor, MediaStore.Audio.Media.ARTIST);
                String album = getStringColumn(cursor, MediaStore.Audio.Media.ALBUM);
                long duration = getLongColumn(cursor, MediaStore.Audio.Media.DURATION);
                int track = getIntColumn(cursor, MediaStore.Audio.Media.TRACK);

                if (title != null && !title.isEmpty()) {
                    metadata.put("title", title);
                }
                if (artist != null && !artist.isEmpty() && !"<unknown>".equals(artist)) {
                    metadata.put("artist", artist);
                }
                if (album != null && !album.isEmpty() && !"<unknown>".equals(album)) {
                    metadata.put("album", album);
                }
                if (duration > 0) {
                    metadata.put("durationMs", duration);
                }
                if (track > 0) {
                    metadata.put("track", track);
                }
            }
        } catch (Exception e) {
            // Silently handle query failures
        } finally {
            if (cursor != null) {
                cursor.close();
            }
        }

        return metadata;
    }

    private String getStringColumn(Cursor cursor, String columnName) {
        int idx = cursor.getColumnIndex(columnName);
        if (idx >= 0 && !cursor.isNull(idx)) {
            return cursor.getString(idx);
        }
        return null;
    }

    private long getLongColumn(Cursor cursor, String columnName) {
        int idx = cursor.getColumnIndex(columnName);
        if (idx >= 0 && !cursor.isNull(idx)) {
            return cursor.getLong(idx);
        }
        return 0;
    }

    private int getIntColumn(Cursor cursor, String columnName) {
        int idx = cursor.getColumnIndex(columnName);
        if (idx >= 0 && !cursor.isNull(idx)) {
            return cursor.getInt(idx);
        }
        return 0;
    }
}
