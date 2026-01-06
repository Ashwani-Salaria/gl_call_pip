package com.gl.gl_call_pip

import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.Color
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.app.Person

private const val ACTION_PIP = "com.gl.gl_call_pip.ACTION"
class OngoingCallService : Service() {

    companion object {
        private const val NOTIF_ID = 9001
        private const val NOTIF_CHANNEL = "ongoing_call"
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val title = intent?.getStringExtra("title") ?: "Ongoing call"
        val text = intent?.getStringExtra("text") ?: "Tap to return"
        val route = intent?.getStringExtra("route") ?: "/"
        val startMs = intent?.getLongExtra("startMs", System.currentTimeMillis()) ?: System.currentTimeMillis()

        startForegroundWithCallChip(title, text, route, startMs)
        return START_STICKY
    }

    private fun startForegroundWithCallChip(title: String, text: String, route: String?, startMs: Long) {
        val ctx = applicationContext
        ensureChannel(ctx)

        val flags = PendingIntent.FLAG_UPDATE_CURRENT or
                (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)

        val launch = ctx.packageManager.getLaunchIntentForPackage(ctx.packageName)?.apply {
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_SINGLE_TOP
            )
            putExtra("from_notification", true)
            if (route != null) putExtra("route", route)
        } ?: return

        val pi = PendingIntent.getActivity(ctx, 1001, launch, flags)

        val person = Person.Builder()
            .setName(title) // chip label
            .setImportant(true)
            .build()
        
        val hangUpIntent = Intent(ACTION_PIP).apply {
            setPackage(ctx.packageName)
            putExtra("id", "end") // Flutter side me onAction('end') milega
        }
        val hangUpPi = PendingIntent.getBroadcast(
            ctx,
            "end".hashCode(),
            hangUpIntent,
            flags
        )

        val builder = NotificationCompat.Builder(ctx, NOTIF_CHANNEL)
            .setSmallIcon(android.R.drawable.stat_sys_phone_call)
            .setContentTitle(title)
            .setContentText(text)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(android.app.Notification.CATEGORY_CALL)
            .setColor(Color.parseColor("#00C853"))
            .setColorized(true)
            .setUsesChronometer(true) // show running timer
            .setWhen(startMs)         // chronometer base = call start time
            .setShowWhen(true)
            .setContentIntent(pi)
            .setStyle(NotificationCompat.CallStyle.forOngoingCall(person, hangUpPi))

        val notif = builder.build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIF_ID,
                notif,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_PHONE_CALL
            )
        } else {
            startForeground(NOTIF_ID, notif)
        }
    }

    private fun ensureChannel(ctx: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
            if (nm.getNotificationChannel(NOTIF_CHANNEL) == null) {
                val ch = android.app.NotificationChannel(
                    NOTIF_CHANNEL, "Ongoing Call", android.app.NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "Return to call"
                    setShowBadge(false)
                    enableVibration(false)
                    enableLights(false)
                }
                nm.createNotificationChannel(ch)
            }
        }
    }

    override fun onDestroy() {
        NotificationManagerCompat.from(applicationContext).cancel(NOTIF_ID)
        super.onDestroy()
    }
}