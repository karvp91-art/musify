package com.example.musify;

import android.app.PendingIntent;
import android.appwidget.AppWidgetManager;
import android.appwidget.AppWidgetProvider;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Canvas;
import android.graphics.Paint;
import android.graphics.PorterDuff;
import android.graphics.PorterDuffXfermode;
import android.graphics.Rect;
import android.graphics.RectF;
import android.os.Build;
import android.os.SystemClock;
import android.view.KeyEvent;
import android.widget.RemoteViews;

import java.io.File;
import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class MusifyWidgetProvider extends AppWidgetProvider {

    public static final String ACTION_PLAY_PAUSE = "com.musify.WIDGET_PLAY_PAUSE";
    public static final String ACTION_PREV = "com.musify.WIDGET_PREV";
    public static final String ACTION_NEXT = "com.musify.WIDGET_NEXT";
    public static final String ACTION_UPDATE_STATE = "com.musify.WIDGET_UPDATE_STATE";

    private static final String PREFS_NAME = "MusifyWidgetPrefs";
    private static final String PREF_TITLE = "title";
    private static final String PREF_ARTIST = "artist";
    private static final String PREF_ARTWORK_PATH = "artworkPath";
    private static final String PREF_ARTWORK_URL = "artworkUrl";
    private static final String PREF_IS_PLAYING = "isPlaying";

    private static final ExecutorService executor = Executors.newSingleThreadExecutor();

    @Override
    public void onUpdate(Context context, AppWidgetManager appWidgetManager, int[] appWidgetIds) {
        super.onUpdate(context, appWidgetManager, appWidgetIds);
        for (int widgetId : appWidgetIds) {
            updateWidgetView(context, appWidgetManager, widgetId);
        }
    }

    @Override
    public void onReceive(Context context, Intent intent) {
        super.onReceive(context, intent);

        String action = intent.getAction();
        if (action == null) return;

        if (ACTION_PLAY_PAUSE.equals(action)) {
            handleMediaAction(context, KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE, "playPause");
        } else if (ACTION_PREV.equals(action)) {
            handleMediaAction(context, KeyEvent.KEYCODE_MEDIA_PREVIOUS, "skipToPrevious");
        } else if (ACTION_NEXT.equals(action)) {
            handleMediaAction(context, KeyEvent.KEYCODE_MEDIA_NEXT, "skipToNext");
        } else if (ACTION_UPDATE_STATE.equals(action)) {
            AppWidgetManager appWidgetManager = AppWidgetManager.getInstance(context);
            ComponentName thisWidget = new ComponentName(context, MusifyWidgetProvider.class);
            int[] allWidgetIds = appWidgetManager.getAppWidgetIds(thisWidget);
            for (int widgetId : allWidgetIds) {
                updateWidgetView(context, appWidgetManager, widgetId);
            }
        }
    }

    private void handleMediaAction(Context context, int keyCode, String actionName) {
        // 1. Notify Flutter plugin if active
        MusifyWidgetPlugin.notifyWidgetAction(actionName);

        // 2. Also send standard media button intent to MediaButtonReceiver / AudioService
        try {
            long eventTime = SystemClock.uptimeMillis();
            Intent downIntent = new Intent(Intent.ACTION_MEDIA_BUTTON);
            downIntent.setComponent(new ComponentName(context, "androidx.media.session.MediaButtonReceiver"));
            downIntent.putExtra(Intent.EXTRA_KEY_EVENT, new KeyEvent(eventTime, eventTime, KeyEvent.ACTION_DOWN, keyCode, 0));
            context.sendBroadcast(downIntent);

            Intent upIntent = new Intent(Intent.ACTION_MEDIA_BUTTON);
            upIntent.setComponent(new ComponentName(context, "androidx.media.session.MediaButtonReceiver"));
            upIntent.putExtra(Intent.EXTRA_KEY_EVENT, new KeyEvent(eventTime, eventTime, KeyEvent.ACTION_UP, keyCode, 0));
            context.sendBroadcast(upIntent);
        } catch (Exception ignored) {
        }
    }

    public static void saveAndBroadcast(Context context, String title, String artist, String artworkPath, String artworkUrl, boolean isPlaying) {
        SharedPreferences prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
        prefs.edit()
                .putString(PREF_TITLE, title)
                .putString(PREF_ARTIST, artist)
                .putString(PREF_ARTWORK_PATH, artworkPath)
                .putString(PREF_ARTWORK_URL, artworkUrl)
                .putBoolean(PREF_IS_PLAYING, isPlaying)
                .apply();

        Intent intent = new Intent(context, MusifyWidgetProvider.class);
        intent.setAction(ACTION_UPDATE_STATE);
        context.sendBroadcast(intent);
    }

    public static void updateWidgetView(Context context, AppWidgetManager appWidgetManager, int widgetId) {
        SharedPreferences prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
        String title = prefs.getString(PREF_TITLE, "Musify");
        String artist = prefs.getString(PREF_ARTIST, "Tap to open player");
        String artworkPath = prefs.getString(PREF_ARTWORK_PATH, null);
        String artworkUrl = prefs.getString(PREF_ARTWORK_URL, null);
        boolean isPlaying = prefs.getBoolean(PREF_IS_PLAYING, false);

        RemoteViews views = new RemoteViews(context.getPackageName(), R.layout.musify_widget);

        views.setTextViewText(R.id.widget_title, title != null && !title.isEmpty() ? title : "Musify");
        views.setTextViewText(R.id.widget_artist, artist != null && !artist.isEmpty() ? artist : "Tap to open player");

        // Set play/pause icon
        if (isPlaying) {
            views.setImageViewResource(R.id.widget_btn_play_pause, R.drawable.ic_widget_pause);
        } else {
            views.setImageViewResource(R.id.widget_btn_play_pause, R.drawable.ic_widget_play);
        }

        // Tap to open app
        Intent openAppIntent = new Intent(context, MainActivity.class);
        openAppIntent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);
        int pendingFlags = PendingIntent.FLAG_UPDATE_CURRENT;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            pendingFlags |= PendingIntent.FLAG_IMMUTABLE;
        }

        PendingIntent openAppPending = PendingIntent.getActivity(context, 0, openAppIntent, pendingFlags);
        views.setOnClickPendingIntent(R.id.widget_container, openAppPending);
        views.setOnClickPendingIntent(R.id.widget_artwork, openAppPending);
        views.setOnClickPendingIntent(R.id.widget_text_container, openAppPending);

        // Previous button
        Intent prevIntent = new Intent(context, MusifyWidgetProvider.class);
        prevIntent.setAction(ACTION_PREV);
        PendingIntent prevPending = PendingIntent.getBroadcast(context, 101, prevIntent, pendingFlags);
        views.setOnClickPendingIntent(R.id.widget_btn_prev, prevPending);

        // Play/Pause button
        Intent playPauseIntent = new Intent(context, MusifyWidgetProvider.class);
        playPauseIntent.setAction(ACTION_PLAY_PAUSE);
        PendingIntent playPausePending = PendingIntent.getBroadcast(context, 102, playPauseIntent, pendingFlags);
        views.setOnClickPendingIntent(R.id.widget_btn_play_pause, playPausePending);

        // Next button
        Intent nextIntent = new Intent(context, MusifyWidgetProvider.class);
        nextIntent.setAction(ACTION_NEXT);
        PendingIntent nextPending = PendingIntent.getBroadcast(context, 103, nextIntent, pendingFlags);
        views.setOnClickPendingIntent(R.id.widget_btn_next, nextPending);

        // Load Artwork
        loadArtwork(context, views, appWidgetManager, widgetId, artworkPath, artworkUrl);

        appWidgetManager.updateAppWidget(widgetId, views);
    }

    private static void loadArtwork(Context context, RemoteViews views, AppWidgetManager appWidgetManager, int widgetId, String artworkPath, String artworkUrl) {
        // Case 1: Local file exists
        if (artworkPath != null && !artworkPath.isEmpty()) {
            File artFile = new File(artworkPath);
            if (artFile.exists()) {
                try {
                    Bitmap bmp = BitmapFactory.decodeFile(artFile.getAbsolutePath());
                    if (bmp != null) {
                        Bitmap rounded = getRoundedCornerBitmap(bmp, 36f);
                        views.setImageViewBitmap(R.id.widget_artwork, rounded);
                        return;
                    }
                } catch (Exception ignored) {
                }
            }
        }

        // Case 2: Remote URL
        if (artworkUrl != null && artworkUrl.startsWith("http")) {
            executor.execute(() -> {
                try {
                    URL url = new URL(artworkUrl);
                    HttpURLConnection conn = (HttpURLConnection) url.openConnection();
                    conn.setConnectTimeout(3000);
                    conn.setReadTimeout(3000);
                    conn.setDoInput(true);
                    conn.connect();
                    InputStream input = conn.getInputStream();
                    Bitmap bmp = BitmapFactory.decodeStream(input);
                    if (bmp != null) {
                        Bitmap rounded = getRoundedCornerBitmap(bmp, 36f);
                        views.setImageViewBitmap(R.id.widget_artwork, rounded);
                        appWidgetManager.updateAppWidget(widgetId, views);
                    }
                } catch (Exception ignored) {
                    views.setImageViewResource(R.id.widget_artwork, R.drawable.ic_widget_music_default);
                }
            });
            return;
        }

        // Default artwork
        views.setImageViewResource(R.id.widget_artwork, R.drawable.ic_widget_music_default);
    }

    public static Bitmap getRoundedCornerBitmap(Bitmap bitmap, float pixels) {
        try {
            int size = Math.min(bitmap.getWidth(), bitmap.getHeight());
            Bitmap output = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888);
            Canvas canvas = new Canvas(output);

            final Paint paint = new Paint();
            final Rect srcRect = new Rect(
                    (bitmap.getWidth() - size) / 2,
                    (bitmap.getHeight() - size) / 2,
                    (bitmap.getWidth() + size) / 2,
                    (bitmap.getHeight() + size) / 2
            );
            final Rect dstRect = new Rect(0, 0, size, size);
            final RectF rectF = new RectF(dstRect);

            paint.setAntiAlias(true);
            canvas.drawARGB(0, 0, 0, 0);
            canvas.drawRoundRect(rectF, pixels, pixels, paint);

            paint.setXfermode(new PorterDuffXfermode(PorterDuff.Mode.SRC_IN));
            canvas.drawBitmap(bitmap, srcRect, dstRect, paint);

            return output;
        } catch (Exception e) {
            return bitmap;
        }
    }
}
