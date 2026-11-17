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
import android.media.MediaScannerConnection;
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
import java.io.RandomAccessFile;
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

            case "scanFile":
                String scanPath = call.argument("filePath");
                if (scanPath != null && context != null) {
                    try {
                        Context appCtx = context.getApplicationContext() != null ? context.getApplicationContext() : context;
                        MediaScannerConnection.scanFile(appCtx, new String[]{scanPath}, null, null);
                        result.success(true);
                    } catch (Exception e) {
                        result.success(false);
                    }
                } else {
                    result.success(false);
                }
                break;

            default:
                result.notImplemented();
                break;
        }
    }

    private static final int[][] MP3_BITRATES_V1 = {
        {0, 32, 64, 96, 128, 160, 192, 224, 256, 288, 320, 352, 384, 416, 448}, // Layer I
        {0, 32, 48, 56, 64,  80,  96, 112, 128, 160, 192, 224, 256, 320, 384}, // Layer II
        {0, 32, 40, 48, 56,  64,  80,  96, 112, 128, 160, 192, 224, 256, 320}, // Layer III
    };
    private static final int[][] MP3_BITRATES_V2 = {
        {0, 32, 48, 56, 64, 80, 96, 112, 128, 144, 160, 176, 192, 224, 256},    // Layer I
        {0, 8,  16, 24, 32, 40, 48,  56,  64,  80,  96, 112, 128, 144, 160},    // Layer II
        {0, 8,  16, 24, 32, 40, 48,  56,  64,  80,  96, 112, 128, 144, 160},    // Layer III
    };
    private static final int[][] MP3_SAMPLE_RATES = {
        {44100, 48000, 32000}, // MPEG1 (version=3)
        {22050, 24000, 16000}, // MPEG2 (version=2)
        {11025, 12000,  8000}, // MPEG2.5 (version=0)
    };

    private static int getMp3Bitrate(int version, int layer, int index) {
        if (index <= 0 || index >= 15) return 0;
        int layerIdx = 3 - layer; // layer: 3=I, 2=II, 1=III -> 0=I, 1=II, 2=III
        if (layerIdx < 0 || layerIdx > 2) return 0;
        if (version == 3) {
            return MP3_BITRATES_V1[layerIdx][index];
        } else {
            return MP3_BITRATES_V2[layerIdx][index];
        }
    }

    private static int getMp3SampleRate(int version, int index) {
        if (index < 0 || index > 2) return 0;
        int verIdx = (version == 3) ? 0 : (version == 2) ? 1 : (version == 0) ? 2 : -1;
        if (verIdx < 0) return 0;
        return MP3_SAMPLE_RATES[verIdx][index];
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
            MediaCodec codec = null;
            try {
                File file = new File(inputPath);
                if (!file.exists()) {
                    runOnMain(() -> result.error("FILE_NOT_FOUND", "Input file not found", null));
                    return;
                }

                extractor = new MediaExtractor();
                extractor.setDataSource(file.getAbsolutePath());

                int audioTrackIndex = -1;
                MediaFormat format = null;
                long durationUs = 0;
                for (int i = 0; i < extractor.getTrackCount(); i++) {
                    MediaFormat f = extractor.getTrackFormat(i);
                    String mime = f.getString(MediaFormat.KEY_MIME);
                    if (mime != null && mime.startsWith("audio/")) {
                        audioTrackIndex = i;
                        format = f;
                        if (f.containsKey(MediaFormat.KEY_DURATION)) {
                            durationUs = f.getLong(MediaFormat.KEY_DURATION);
                        }
                        break;
                    }
                }

                if (audioTrackIndex < 0 || durationUs <= 0 || format == null) {
                    runOnMain(() -> result.success(null));
                    return;
                }

                extractor.selectTrack(audioTrackIndex);
                String mime = format.getString(MediaFormat.KEY_MIME);

                codec = MediaCodec.createDecoderByType(mime);
                codec.configure(format, null, null, 0);
                codec.start();

                long intervalUs = durationUs / targetSamples;
                double[] amplitudes = new double[targetSamples];
                MediaCodec.BufferInfo bufferInfo = new MediaCodec.BufferInfo();
                double maxPeak = 0.0;

                for (int i = 0; i < targetSamples; i++) {
                    long targetTimeUs = i * intervalUs;
                    extractor.seekTo(targetTimeUs, MediaExtractor.SEEK_TO_CLOSEST_SYNC);
                    codec.flush();

                    int inIndex = codec.dequeueInputBuffer(10000);
                    if (inIndex >= 0) {
                        ByteBuffer inputBuffer = codec.getInputBuffer(inIndex);
                        if (inputBuffer != null) {
                            int sampleSize = extractor.readSampleData(inputBuffer, 0);
                            if (sampleSize > 0) {
                                long sampleTime = extractor.getSampleTime();
                                codec.queueInputBuffer(inIndex, 0, sampleSize, sampleTime, 0);
                            } else {
                                codec.queueInputBuffer(inIndex, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM);
                            }
                        }
                    }

                    int outIndex = codec.dequeueOutputBuffer(bufferInfo, 10000);
                    double amp = 0.0;
                    if (outIndex >= 0) {
                        ByteBuffer outputBuffer = codec.getOutputBuffer(outIndex);
                        if (outputBuffer != null && bufferInfo.size > 0) {
                            outputBuffer.position(bufferInfo.offset);
                            outputBuffer.limit(bufferInfo.offset + bufferInfo.size);

                            int shortCount = bufferInfo.size / 2;
                            int count = Math.min(shortCount, 512);
                            long sumSq = 0;
                            for (int s = 0; s < count; s++) {
                                short val = outputBuffer.getShort();
                                sumSq += (long) val * val;
                            }
                            amp = Math.sqrt((double) sumSq / Math.max(1, count));
                        }
                        codec.releaseOutputBuffer(outIndex, false);
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
                if (codec != null) {
                    try { codec.stop(); } catch (Exception ignored) {}
                    try { codec.release(); } catch (Exception ignored) {}
                }
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
                String finalOutputPath = outputPath;

                if (isMp3) {
                    success = trimMp3ByTime(inputFile, outFile, startMsNum.longValue(), endMsNum.longValue());
                }

                if (!success) {
                    // For non-MP3 files, or if MP3 frame scan failed:
                    // If output extension is .mp3 but we must use MediaMuxer (which produces MPEG_4),
                    // adjust output file extension to .m4a so the container matches the extension.
                    if (finalOutputPath.toLowerCase().endsWith(".mp3")) {
                        finalOutputPath = finalOutputPath.substring(0, finalOutputPath.length() - 4) + ".m4a";
                    }
                    success = trimWithMediaMuxer(inputPath, finalOutputPath, startUs, endUs);
                }

                final boolean finalSuccess = success;
                final String resolvedOutputPath = finalOutputPath;
                if (finalSuccess && context != null) {
                    try {
                        Context appCtx = context.getApplicationContext() != null ? context.getApplicationContext() : context;
                        MediaScannerConnection.scanFile(appCtx, new String[]{resolvedOutputPath}, null, null);
                    } catch (Exception ignored) {}
                }
                runOnMain(() -> {
                    if (finalSuccess) {
                        Map<String, Object> res = new HashMap<>();
                        res.put("success", true);
                        res.put("outputPath", resolvedOutputPath);
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
        RandomAccessFile raf = null;
        FileOutputStream fos = null;
        try {
            long fileLength = inputFile.length();
            if (fileLength < 128) return false;

            raf = new RandomAccessFile(inputFile, "r");
            fos = new FileOutputStream(outputFile);

            // 1. Detect and preserve ID3v2 header
            long audioStartOffset = 0;
            byte[] id3Header = new byte[10];
            if (raf.read(id3Header) == 10) {
                if (id3Header[0] == 'I' && id3Header[1] == 'D' && id3Header[2] == '3') {
                    int tagSize = ((id3Header[6] & 0x7F) << 21)
                            | ((id3Header[7] & 0x7F) << 14)
                            | ((id3Header[8] & 0x7F) << 7)
                            | (id3Header[9] & 0x7F);
                    audioStartOffset = 10L + tagSize;
                    if (audioStartOffset > fileLength) {
                        audioStartOffset = 0;
                    } else {
                        // Write the ID3v2 header and tags to output file
                        raf.seek(0);
                        byte[] id3Buffer = new byte[8192];
                        long id3Remaining = audioStartOffset;
                        while (id3Remaining > 0) {
                            int toRead = (int) Math.min(id3Buffer.length, id3Remaining);
                            int read = raf.read(id3Buffer, 0, toRead);
                            if (read <= 0) break;
                            fos.write(id3Buffer, 0, read);
                            id3Remaining -= read;
                        }
                    }
                }
            }

            // 2. Scan MP3 frames to index [fileOffset, cumulativeMs, frameSize]
            raf.seek(audioStartOffset);
            List<long[]> frames = new ArrayList<>(); // each element: [byteOffset, cumulativeMs, frameSize]
            long pos = audioStartOffset;
            double cumulativeMs = 0.0;
            byte[] headerBuf = new byte[4];

            while (pos + 4 <= fileLength) {
                raf.seek(pos);
                if (raf.read(headerBuf) != 4) break;

                int b0 = headerBuf[0] & 0xFF;
                int b1 = headerBuf[1] & 0xFF;
                int b2 = headerBuf[2] & 0xFF;
                int b3 = headerBuf[3] & 0xFF;

                if (b0 == 0xFF && (b1 & 0xE0) == 0xE0) {
                    int version = (b1 >> 3) & 0x03; // 0=2.5, 2=2, 3=1
                    int layer = (b1 >> 1) & 0x03;   // 1=III, 2=II, 3=I
                    int brIdx = (b2 >> 4) & 0x0F;
                    int srIdx = (b2 >> 2) & 0x03;
                    int padding = (b2 >> 1) & 0x01;

                    if (version == 1 || layer == 0 || brIdx == 0 || brIdx == 15 || srIdx == 3) {
                        pos++;
                        continue;
                    }

                    int bitrate = getMp3Bitrate(version, layer, brIdx);
                    int sampleRate = getMp3SampleRate(version, srIdx);
                    if (bitrate <= 0 || sampleRate <= 0) {
                        pos++;
                        continue;
                    }

                    int samplesPerFrame;
                    int frameSize;
                    if (layer == 3) { // Layer I
                        samplesPerFrame = 384;
                        frameSize = ((12 * bitrate * 1000) / sampleRate + padding) * 4;
                    } else if (layer == 2) { // Layer II
                        samplesPerFrame = 1152;
                        frameSize = (144 * bitrate * 1000) / sampleRate + padding;
                    } else { // Layer III
                        samplesPerFrame = (version == 3) ? 1152 : 576;
                        int multiplier = (version == 3) ? 144 : 72;
                        frameSize = (multiplier * bitrate * 1000) / sampleRate + padding;
                    }

                    if (frameSize <= 0 || pos + frameSize > fileLength) {
                        break;
                    }

                    double frameDurationMs = ((double) samplesPerFrame * 1000.0) / sampleRate;
                    frames.add(new long[]{pos, (long) cumulativeMs, frameSize});
                    cumulativeMs += frameDurationMs;
                    pos += frameSize;
                } else {
                    pos++;
                }
            }

            if (frames.isEmpty()) {
                return false;
            }

            // 3. Find start and end frame indices
            int startFrame = 0;
            int endFrame = frames.size() - 1;
            for (int i = 0; i < frames.size(); i++) {
                if (frames.get(i)[1] >= startMs) {
                    startFrame = i;
                    break;
                }
            }
            for (int i = frames.size() - 1; i >= 0; i--) {
                if (frames.get(i)[1] <= endMs) {
                    endFrame = i;
                    break;
                }
            }
            if (startFrame > endFrame) {
                endFrame = startFrame;
            }

            long startByte = frames.get(startFrame)[0];
            long endByte = frames.get(endFrame)[0] + frames.get(endFrame)[2];
            long bytesToCopy = endByte - startByte;

            // 4. Stream copy the exact frame slices
            raf.seek(startByte);
            byte[] copyBuffer = new byte[8192];
            long remaining = bytesToCopy;
            while (remaining > 0) {
                int toRead = (int) Math.min(copyBuffer.length, remaining);
                int read = raf.read(copyBuffer, 0, toRead);
                if (read <= 0) break;
                fos.write(copyBuffer, 0, read);
                remaining -= read;
            }

            fos.flush();
            return true;
        } catch (Exception e) {
            return false;
        } finally {
            if (raf != null) {
                try { raf.close(); } catch (Exception ignored) {}
            }
            if (fos != null) {
                try { fos.close(); } catch (Exception ignored) {}
            }
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
