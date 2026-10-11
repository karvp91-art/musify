package com.example.musify;

import android.app.Activity;
import android.content.ContentResolver;
import android.content.ContentValues;
import android.content.Context;
import android.content.Intent;
import android.media.MediaCodec;
import android.media.MediaExtractor;
import android.media.MediaFormat;
import android.media.MediaMuxer;
import android.media.RingtoneManager;
import android.net.Uri;
import android.os.Build;
import android.os.Environment;
import android.provider.MediaStore;
import android.provider.Settings;

import androidx.annotation.NonNull;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.nio.ByteBuffer;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

public class RingtonePlugin implements FlutterPlugin, ActivityAware, MethodChannel.MethodCallHandler {
    private MethodChannel channel;
    private Context context;
    private Activity activity;
    private final android.os.Handler mainHandler = new android.os.Handler(android.os.Looper.getMainLooper());

    private void runOnMain(Runnable r) {
        if (activity != null) {
            activity.runOnUiThread(r);
        } else {
            mainHandler.post(r);
        }
    }

    @Override
    public void onAttachedToEngine(@NonNull FlutterPlugin.FlutterPluginBinding binding) {
        context = binding.getApplicationContext();
        channel = new MethodChannel(binding.getBinaryMessenger(), "com.musify/ringtone");
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
    public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
        activity = binding.getActivity();
    }

    @Override
    public void onDetachedFromActivityForConfigChanges() {
        activity = null;
    }

    @Override
    public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) {
        activity = binding.getActivity();
    }

    @Override
    public void onDetachedFromActivity() {
        activity = null;
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        switch (call.method) {
            case "canWriteSettings":
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    result.success(Settings.System.canWrite(context));
                } else {
                    result.success(true);
                }
                break;

            case "openWriteSettings":
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    Intent intent = new Intent(Settings.ACTION_MANAGE_WRITE_SETTINGS);
                    intent.setData(Uri.parse("package:" + context.getPackageName()));
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                    context.startActivity(intent);
                    result.success(true);
                } else {
                    result.success(true);
                }
                break;

            case "trimAudio":
                handleTrimAudio(call, result);
                break;

            case "extractWaveform":
                handleExtractWaveform(call, result);
                break;

            case "setRingtone":
                handleSetRingtone(call, result);
                break;

            default:
                result.notImplemented();
                break;
        }
    }

    private void handleExtractWaveform(MethodCall call, MethodChannel.Result result) {
        String inputPath = call.argument("inputPath");
        Integer sampleCountArg = call.argument("samples");
        final int targetSamples = (sampleCountArg != null && sampleCountArg > 0) ? sampleCountArg : 64;

        if (inputPath == null) {
            result.error("INVALID_ARGS", "Missing inputPath", null);
            return;
        }

        new Thread(() -> {
            MediaExtractor extractor = null;
            try {
                File file = new File(inputPath);
                if (!file.exists()) {
                    runOnMain(() -> result.error("FILE_NOT_FOUND", "Input file not found", null));
                    return;
                }

                extractor = new MediaExtractor();
                extractor.setDataSource(file.getAbsolutePath());

                int audioTrackIndex = -1;
                long durationUs = 0;
                for (int i = 0; i < extractor.getTrackCount(); i++) {
                    MediaFormat f = extractor.getTrackFormat(i);
                    String mime = f.getString(MediaFormat.KEY_MIME);
                    if (mime != null && mime.startsWith("audio/")) {
                        audioTrackIndex = i;
                        if (f.containsKey(MediaFormat.KEY_DURATION)) {
                            durationUs = f.getLong(MediaFormat.KEY_DURATION);
                        }
                        break;
                    }
                }

                if (audioTrackIndex < 0 || durationUs <= 0) {
                    runOnMain(() -> result.success(null));
                    return;
                }

                extractor.selectTrack(audioTrackIndex);

                long intervalUs = durationUs / targetSamples;
                double[] amplitudes = new double[targetSamples];
                ByteBuffer buffer = ByteBuffer.allocateDirect(16384);

                double maxPeak = 0.0;
                for (int i = 0; i < targetSamples; i++) {
                    long targetTimeUs = i * intervalUs;
                    extractor.seekTo(targetTimeUs, MediaExtractor.SEEK_TO_CLOSEST_SYNC);
                    int sampleSize = extractor.readSampleData(buffer, 0);

                    double amp = 0.0;
                    if (sampleSize > 0) {
                        buffer.rewind();
                        int count = Math.min(sampleSize / 2, 256);
                        long sumSq = 0;
                        for (int s = 0; s < count; s++) {
                            short val = buffer.getShort();
                            sumSq += (long) val * val;
                        }
                        amp = Math.sqrt((double) sumSq / Math.max(1, count));
                    }
                    amplitudes[i] = amp;
                    if (amp > maxPeak) {
                        maxPeak = amp;
                    }
                }

                List<Double> normalized = new ArrayList<>(targetSamples);
                for (double a : amplitudes) {
                    double norm = maxPeak > 0 ? (a / maxPeak) : 0.4;
                    norm = Math.max(0.18, Math.min(1.0, norm));
                    normalized.add(norm);
                }

                runOnMain(() -> result.success(normalized));
            } catch (Exception e) {
                runOnMain(() -> result.success(null));
            } finally {
                if (extractor != null) {
                    try { extractor.release(); } catch (Exception ignored) {}
                }
            }
        }).start();
    }

    private void handleTrimAudio(MethodCall call, MethodChannel.Result result) {
        String inputPath = call.argument("inputPath");
        String outputPath = call.argument("outputPath");
        Number startMsNum = call.argument("startMs");
        Number endMsNum = call.argument("endMs");
        Number fadeInMsNum = call.argument("fadeInMs");
        Number fadeOutMsNum = call.argument("fadeOutMs");

        if (inputPath == null || outputPath == null || startMsNum == null || endMsNum == null) {
            result.error("INVALID_ARGS", "Missing required arguments for trimAudio", null);
            return;
        }

        long startUs = startMsNum.longValue() * 1000L;
        long endUs = endMsNum.longValue() * 1000L;
        long fadeInMs = fadeInMsNum != null ? fadeInMsNum.longValue() : 0L;
        long fadeOutMs = fadeOutMsNum != null ? fadeOutMsNum.longValue() : 0L;

        new Thread(() -> {
            try {
                File inputFile = new File(inputPath);
                if (!inputFile.exists()) {
                    runOnMain(() -> result.error("FILE_NOT_FOUND", "Input file not found", null));
                    return;
                }

                File outFile = new File(outputPath);
                if (outFile.getParentFile() != null && !outFile.getParentFile().exists()) {
                    outFile.getParentFile().mkdirs();
                }

                // If MP3, attempt clean frame-based slicing; fallback to MediaExtractor+MediaMuxer
                boolean isMp3 = inputPath.toLowerCase().endsWith(".mp3") || outputPath.toLowerCase().endsWith(".mp3");
                boolean success = false;

                if (isMp3) {
                    success = trimMp3ByTime(inputFile, outFile, startMsNum.longValue(), endMsNum.longValue());
                }

                if (!success) {
                    success = trimWithMediaMuxer(inputPath, outputPath, startUs, endUs);
                }

                final boolean finalSuccess = success;
                runOnMain(() -> {
                    if (finalSuccess) {
                        Map<String, Object> res = new HashMap<>();
                        res.put("success", true);
                        res.put("outputPath", outputPath);
                        result.success(res);
                    } else {
                        result.error("TRIM_FAILED", "Failed to trim audio", null);
                    }
                });
            } catch (Exception e) {
                runOnMain(() -> result.error("TRIM_ERROR", e.getMessage(), null));
            }
        }).start();
    }

    private boolean trimWithMediaMuxer(String inputPath, String outputPath, long startUs, long endUs) {
        MediaExtractor extractor = null;
        MediaMuxer muxer = null;
        try {
            extractor = new MediaExtractor();
            extractor.setDataSource(inputPath);

            int trackCount = extractor.getTrackCount();
            int audioTrackIndex = -1;
            MediaFormat format = null;

            for (int i = 0; i < trackCount; i++) {
                MediaFormat f = extractor.getTrackFormat(i);
                String mime = f.getString(MediaFormat.KEY_MIME);
                if (mime != null && mime.startsWith("audio/")) {
                    audioTrackIndex = i;
                    format = f;
                    break;
                }
            }

            if (audioTrackIndex < 0 || format == null) {
                return false;
            }

            extractor.selectTrack(audioTrackIndex);
            extractor.seekTo(startUs, MediaExtractor.SEEK_TO_CLOSEST_SYNC);

            int outputFormat = MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4;
            muxer = new MediaMuxer(outputPath, outputFormat);
            int muxerTrackIndex = muxer.addTrack(format);
            muxer.start();

            int maxBufferSize = format.containsKey(MediaFormat.KEY_MAX_INPUT_SIZE)
                    ? format.getInteger(MediaFormat.KEY_MAX_INPUT_SIZE)
                    : 1024 * 1024;
            ByteBuffer buffer = ByteBuffer.allocateDirect(maxBufferSize);
            MediaCodec.BufferInfo bufferInfo = new MediaCodec.BufferInfo();

            while (true) {
                bufferInfo.size = extractor.readSampleData(buffer, 0);
                if (bufferInfo.size < 0) {
                    break;
                }

                long sampleTimeUs = extractor.getSampleTime();
                if (sampleTimeUs > endUs) {
                    break;
                }

                if (sampleTimeUs >= startUs) {
                    bufferInfo.presentationTimeUs = sampleTimeUs - startUs;
                    bufferInfo.flags = extractor.getSampleFlags();
                    muxer.writeSampleData(muxerTrackIndex, buffer, bufferInfo);
                }

                extractor.advance();
            }

            muxer.stop();
            return true;
        } catch (Exception e) {
            return false;
        } finally {
            if (extractor != null) {
                try { extractor.release(); } catch (Exception ignored) {}
            }
            if (muxer != null) {
                try { muxer.release(); } catch (Exception ignored) {}
            }
        }
    }

    private boolean trimMp3ByTime(File inputFile, File outputFile, long startMs, long endMs) {
        try (FileInputStream in = new FileInputStream(inputFile);
             FileOutputStream out = new FileOutputStream(outputFile)) {

            long fileLength = inputFile.length();
            if (fileLength == 0) return false;

            // Determine total duration via MediaExtractor
            MediaExtractor extractor = new MediaExtractor();
            extractor.setDataSource(inputFile.getAbsolutePath());
            long durationUs = 0;
            for (int i = 0; i < extractor.getTrackCount(); i++) {
                MediaFormat f = extractor.getTrackFormat(i);
                String mime = f.getString(MediaFormat.KEY_MIME);
                if (mime != null && mime.startsWith("audio/")) {
                    if (f.containsKey(MediaFormat.KEY_DURATION)) {
                        durationUs = f.getLong(MediaFormat.KEY_DURATION);
                        break;
                    }
                }
            }
            extractor.release();

            long totalDurationMs = durationUs > 0 ? durationUs / 1000L : 0;
            if (totalDurationMs <= 0) return false;

            // Calculate byte offsets
            long startByte = (long) (((double) startMs / (double) totalDurationMs) * fileLength);
            long endByte = (long) (((double) endMs / (double) totalDurationMs) * fileLength);

            startByte = Math.max(0, Math.min(startByte, fileLength));
            endByte = Math.max(startByte, Math.min(endByte, fileLength));
            long bytesToRead = endByte - startByte;

            // Skip to startByte
            long skipped = in.skip(startByte);

            byte[] buffer = new byte[8192];
            long totalWritten = 0;
            while (totalWritten < bytesToRead) {
                int toRead = (int) Math.min(buffer.length, bytesToRead - totalWritten);
                int read = in.read(buffer, 0, toRead);
                if (read <= 0) break;
                out.write(buffer, 0, read);
                totalWritten += read;
            }

            out.flush();
            return totalWritten > 0;
        } catch (Exception e) {
            return false;
        }
    }

    private void handleSetRingtone(MethodCall call, MethodChannel.Result result) {
        String filePath = call.argument("filePath");
        String title = call.argument("title");
        Number typeNum = call.argument("type"); // 1=Ringtone, 2=Notification, 4=Alarm

        if (filePath == null) {
            result.error("INVALID_ARGS", "filePath is required", null);
            return;
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            if (!Settings.System.canWrite(context)) {
                Map<String, Object> res = new HashMap<>();
                res.put("success", false);
                res.put("needPermission", true);
                result.success(res);
                return;
            }
        }

        File file = new File(filePath);
        if (!file.exists()) {
            result.error("FILE_NOT_FOUND", "File does not exist", null);
            return;
        }

        int type = typeNum != null ? typeNum.intValue() : RingtoneManager.TYPE_RINGTONE;
        String ringtoneTitle = title != null && !title.isEmpty() ? title : file.getName();
        String mimeType = filePath.endsWith(".m4a") ? "audio/mp4" : "audio/mpeg";

        String relativeDir;
        if ((type & RingtoneManager.TYPE_NOTIFICATION) != 0) {
            relativeDir = Environment.DIRECTORY_NOTIFICATIONS;
        } else if ((type & RingtoneManager.TYPE_ALARM) != 0) {
            relativeDir = Environment.DIRECTORY_ALARMS;
        } else {
            relativeDir = Environment.DIRECTORY_RINGTONES;
        }

        try {
            Uri newUri = null;

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                ContentValues values = new ContentValues();
                values.put(MediaStore.Audio.Media.DISPLAY_NAME, file.getName());
                values.put(MediaStore.Audio.Media.TITLE, ringtoneTitle);
                values.put(MediaStore.Audio.Media.MIME_TYPE, mimeType);
                values.put(MediaStore.Audio.Media.RELATIVE_PATH, relativeDir + "/");
                values.put(MediaStore.Audio.Media.IS_RINGTONE, (type & RingtoneManager.TYPE_RINGTONE) != 0 ? 1 : 0);
                values.put(MediaStore.Audio.Media.IS_NOTIFICATION, (type & RingtoneManager.TYPE_NOTIFICATION) != 0 ? 1 : 0);
                values.put(MediaStore.Audio.Media.IS_ALARM, (type & RingtoneManager.TYPE_ALARM) != 0 ? 1 : 0);
                values.put(MediaStore.Audio.Media.IS_MUSIC, 0);
                values.put(MediaStore.Audio.Media.IS_PENDING, 1);

                Uri collectionUri = MediaStore.Audio.Media.EXTERNAL_CONTENT_URI;

                // Clean up previous entry with identical display name if present
                try {
                    context.getContentResolver().delete(
                            collectionUri,
                            MediaStore.Audio.Media.DISPLAY_NAME + "=? AND " + MediaStore.Audio.Media.RELATIVE_PATH + "=?",
                            new String[]{file.getName(), relativeDir + "/"}
                    );
                } catch (Exception ignored) {}

                newUri = context.getContentResolver().insert(collectionUri, values);
                if (newUri != null) {
                    try (InputStream in = new FileInputStream(file);
                         OutputStream out = context.getContentResolver().openOutputStream(newUri)) {
                        if (out != null) {
                            byte[] buffer = new byte[8192];
                            int read;
                            while ((read = in.read(buffer)) > 0) {
                                out.write(buffer, 0, read);
                            }
                            out.flush();
                        }
                    }

                    // Release pending state so it is visible to system services
                    ContentValues pendingValues = new ContentValues();
                    pendingValues.put(MediaStore.Audio.Media.IS_PENDING, 0);
                    context.getContentResolver().update(newUri, pendingValues, null, null);
                }
            } else {
                File destDir = Environment.getExternalStoragePublicDirectory(relativeDir);
                if (!destDir.exists()) {
                    destDir.mkdirs();
                }
                File destFile = new File(destDir, file.getName());
                try (InputStream in = new FileInputStream(file);
                     OutputStream out = new FileOutputStream(destFile)) {
                    byte[] buffer = new byte[8192];
                    int read;
                    while ((read = in.read(buffer)) > 0) {
                        out.write(buffer, 0, read);
                    }
                    out.flush();
                }

                ContentValues values = new ContentValues();
                values.put(MediaStore.MediaColumns.DATA, destFile.getAbsolutePath());
                values.put(MediaStore.MediaColumns.TITLE, ringtoneTitle);
                values.put(MediaStore.MediaColumns.MIME_TYPE, mimeType);
                values.put(MediaStore.Audio.Media.IS_RINGTONE, (type & RingtoneManager.TYPE_RINGTONE) != 0);
                values.put(MediaStore.Audio.Media.IS_NOTIFICATION, (type & RingtoneManager.TYPE_NOTIFICATION) != 0);
                values.put(MediaStore.Audio.Media.IS_ALARM, (type & RingtoneManager.TYPE_ALARM) != 0);
                values.put(MediaStore.Audio.Media.IS_MUSIC, false);

                try {
                    context.getContentResolver().delete(
                            MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
                            MediaStore.MediaColumns.DATA + "=?",
                            new String[]{destFile.getAbsolutePath()}
                    );
                } catch (Exception ignored) {}

                newUri = context.getContentResolver().insert(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, values);
            }

            if (newUri != null) {
                Context targetContext = activity != null ? activity : context;
                if ((type & RingtoneManager.TYPE_RINGTONE) != 0) {
                    RingtoneManager.setActualDefaultRingtoneUri(targetContext, RingtoneManager.TYPE_RINGTONE, newUri);
                }
                if ((type & RingtoneManager.TYPE_NOTIFICATION) != 0) {
                    RingtoneManager.setActualDefaultRingtoneUri(targetContext, RingtoneManager.TYPE_NOTIFICATION, newUri);
                }
                if ((type & RingtoneManager.TYPE_ALARM) != 0) {
                    RingtoneManager.setActualDefaultRingtoneUri(targetContext, RingtoneManager.TYPE_ALARM, newUri);
                }

                Map<String, Object> res = new HashMap<>();
                res.put("success", true);
                res.put("needPermission", false);
                res.put("uri", newUri.toString());
                result.success(res);
            } else {
                result.error("INSERT_FAILED", "Failed to register ringtone into MediaStore", null);
            }
        } catch (Exception e) {
            android.util.Log.e("RingtonePlugin", "Error setting ringtone", e);
            result.error("RINGTONE_ERROR", e.getMessage() != null ? e.getMessage() : e.toString(), null);
        }
    }
}
