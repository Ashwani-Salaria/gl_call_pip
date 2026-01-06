package com.gl.gl_call_pip

import android.app.Activity
import android.app.PendingIntent
import android.app.PictureInPictureParams
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.Icon
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Log
import android.util.Rational
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

class GlCallPipPlugin : FlutterPlugin,
    MethodChannel.MethodCallHandler,
    ActivityAware,
    PluginRegistry.UserLeaveHintListener,
    PluginRegistry.NewIntentListener {

    // Channel/context/activity
    private lateinit var channel: MethodChannel
    private lateinit var applicationContext: Context
    private var activity: Activity? = null
    private var binding: ActivityPluginBinding? = null

    // PiP state
    private var autoEnterOnUserLeave: Boolean = false
    private var aspectWidth: Int = 9
    private var aspectHeight: Int = 16
    private var lastActions: List<Map<String, Any?>> = emptyList()

    // Broadcast receiver for PiP actions
    private var receiverRegistered = false
    private val ACTION_PIP = "com.gl.gl_call_pip.ACTION"

    // Main thread handler
    private val mainHandler = Handler(Looper.getMainLooper())

    // Notification
    private val NOTIF_ID = 9001
    private val NOTIF_CHANNEL = "ongoing_call"

    // ===== OVERLAY (GLOBAL GREEN BANNER) =====
    private var overlayView: View? = null
    private var windowManager: WindowManager? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "gl_call_pip")
        channel.setMethodCallHandler(this)
        Log.d("CallPipPlugin", "Attached to engine")
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    // ActivityAware
    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        this.activity = binding.activity
        this.binding = binding
        binding.addOnUserLeaveHintListener(this)
        binding.addOnNewIntentListener(this)
        registerReceiver()

        // Handle launch via notification/overlay clicks
        checkInitialIntent(binding.activity.intent)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        binding?.removeOnUserLeaveHintListener(this)
        binding?.removeOnNewIntentListener(this)
        unregisterReceiver()
        hideGlobalBanner()
        binding = null
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivity() {
        binding?.removeOnUserLeaveHintListener(this)
        binding?.removeOnNewIntentListener(this)
        unregisterReceiver()
        hideGlobalBanner()
        binding = null
        activity = null
    }

    // Minimize hint
    override fun onUserLeaveHint() {
        try { channel.invokeMethod("onUserLeaveHint", null) } catch (_: Exception) {}

        if (autoEnterOnUserLeave && Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            enterPipInternal()
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            mainHandler.postDelayed({
                val inPip = activity?.isInPictureInPictureMode == true
                if (inPip) {
                    try { channel.invokeMethod("onPipModeChanged", mapOf("inPip" to true)) } catch (_: Exception) {}
                }
            }, 200)
        }
    }

    // New intents (notif/overlay tap)
    override fun onNewIntent(intent: Intent): Boolean {
        checkInitialIntent(intent)
        return false
    }

    private fun checkInitialIntent(intent: Intent?) {
        if (intent == null) return
        val fromNotif = intent.getBooleanExtra("from_notification", false)
        val fromOverlay = intent.getBooleanExtra("from_overlay", false)
        if (fromNotif || fromOverlay) {
            val route = intent.getStringExtra("route") ?: "/"
            mainHandler.post {
                try {
                    channel.invokeMethod("onOpenFromNotification", mapOf("route" to route))
                } catch (_: Exception) {}
            }
            // Avoid re-trigger on config change
            intent.removeExtra("from_notification")
            intent.removeExtra("from_overlay")
            intent.removeExtra("route")
        }
    }

    // Method channel
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isAvailable" -> result.success(isPipSupported())
            "isInPip" -> result.success(activity?.isInPictureInPictureMode == true)

            "enter" -> {
                val width = (call.argument<Int>("width") ?: 9).coerceAtLeast(1)
                val height = (call.argument<Int>("height") ?: 16).coerceAtLeast(1)
                aspectWidth = width
                aspectHeight = height
                autoEnterOnUserLeave = call.argument<Boolean>("autoEnterOnMinimize") ?: false

                val raw = call.argument<List<Any>>("actions") ?: emptyList()
                lastActions = raw.mapNotNull { it as? Map<String, Any?> }

                val ok = enterPipInternal()
                result.success(ok)
            }

            "setAutoEnterOnMinimize" -> {
                autoEnterOnUserLeave = call.argument<Boolean>("enabled") ?: false
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    updateParamsInternal()
                }
                result.success(null)
            }

            "updateAspectRatio" -> {
                val width = (call.argument<Int>("width") ?: aspectWidth).coerceAtLeast(1)
                val height = (call.argument<Int>("height") ?: aspectHeight).coerceAtLeast(1)
                aspectWidth = width
                aspectHeight = height
                updateParamsInternal()
                result.success(null)
            }

            "updateActions" -> {
                val raw = call.argument<List<Any>>("actions") ?: emptyList()
                lastActions = raw.mapNotNull { it as? Map<String, Any?> }
                updateParamsInternal()
                result.success(null)
            }

            "bringToForeground" -> {
                bringToForegroundInternal()
                result.success(null)
            }

            // Notifications (already working)
            "showOngoingCallNotification" -> {
                val title = call.argument<String>("title") ?: "Call running"
                val text = call.argument<String>("text") ?: "Tap to return"
                val route = call.argument<String>("route") ?: "/"
                showOngoingNotif(title, text, route)
                result.success(null)
            }

            "cancelOngoingCallNotification" -> {
                cancelOngoingNotif()
                result.success(null)
            }

            // ===== Overlay banner methods =====
            "hasOverlayPermission" -> {
                result.success(hasOverlayPermission())
            }

            "requestOverlayPermission" -> {
                requestOverlayPermission()
                result.success(null)
            }

            "showGlobalCallBanner" -> {
                val title = call.argument<String>("title") ?: "Ongoing call"
                val text = call.argument<String>("text") ?: "Tap to return"
                val route = call.argument<String>("route") ?: "/"
                showGlobalBanner(title, text, route)
                result.success(null)
            }

            "hideGlobalCallBanner" -> {
                hideGlobalBanner()
                result.success(null)
            }

            "startOngoingCallChip" -> {
                val title = call.argument<String>("title") ?: "Ongoing call"
                val text = call.argument<String>("text") ?: "Tap to return"
                val route = call.argument<String>("route") ?: "/"
                val startMs = call.argument<Number>("startMs")?.toLong() ?: System.currentTimeMillis()
                startOngoingCallChip(title, text, route, startMs)
                result.success(null)
            }
            "stopOngoingCallChip" -> {
                stopOngoingCallChip()
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    private fun isPipSupported(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        return applicationContext.packageManager.hasSystemFeature(
            PackageManager.FEATURE_PICTURE_IN_PICTURE
        )
    }

    private fun enterPipInternal(): Boolean {
        val act = activity ?: return false
        if (!isPipSupported()) return false
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val ratio = Rational(aspectWidth, aspectHeight)
            val builder = PictureInPictureParams.Builder().setAspectRatio(ratio)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                builder.setAutoEnterEnabled(autoEnterOnUserLeave)
            }
            val actions = buildRemoteActions(applicationContext, lastActions)
            if (actions.isNotEmpty()) builder.setActions(actions)
            val params = builder.build()
            return try {
                act.setPictureInPictureParams(params)
                val ok = act.enterPictureInPictureMode(params)
                if (ok) {
                    try { channel.invokeMethod("onPipModeChanged", mapOf("inPip" to true)) } catch (_: Exception) {}
                }
                ok
            } catch (e: Exception) {
                Log.e("CallPipPlugin", "enterPiP failed", e)
                false
            }
        }
        return false
    }

    private fun updateParamsInternal() {
        val act = activity ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val ratio = Rational(aspectWidth, aspectHeight)
            val builder = PictureInPictureParams.Builder().setAspectRatio(ratio)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                builder.setAutoEnterEnabled(autoEnterOnUserLeave)
            }
            val actions = buildRemoteActions(applicationContext, lastActions)
            if (actions.isNotEmpty()) builder.setActions(actions)
            act.setPictureInPictureParams(builder.build())
        }
    }

    private fun bringToForegroundInternal() {
        val act = activity ?: return
        val intent = Intent(act, act.javaClass).apply {
            addFlags(
                Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or
                Intent.FLAG_ACTIVITY_SINGLE_TOP or
                Intent.FLAG_ACTIVITY_CLEAR_TOP
            )
        }
        act.startActivity(intent)
    }

    private fun registerReceiver() {
        if (!receiverRegistered) {
            applicationContext.registerReceiver(pipReceiver, IntentFilter(ACTION_PIP))
            receiverRegistered = true
        }
    }

    private fun unregisterReceiver() {
        if (receiverRegistered) {
            applicationContext.unregisterReceiver(pipReceiver)
            receiverRegistered = false
        }
    }

    private val pipReceiver = object : BroadcastReceiver() {
        override fun onReceive(ctx: Context?, intent: Intent?) {
            if (intent?.action != ACTION_PIP) return
            val id = intent.getStringExtra("id") ?: return
            val extrasBundle = intent.getBundleExtra("extras")
            val extrasMap = extrasBundle?.let { bundleToMap(it) }

            mainHandler.post {
                try {
                    channel.invokeMethod("onAction", mapOf("id" to id, "extras" to extrasMap))
                } catch (_: Exception) {}
            }
        }
    }

    private fun buildRemoteActions(ctx: Context, actions: List<Map<String, Any?>>): List<android.app.RemoteAction> {
        return actions.mapNotNull { a ->
            val id = a["id"] as? String ?: return@mapNotNull null
            val title = (a["title"] as? String) ?: id
            val iconName = a["icon"] as? String

            val icon = run {
                val resId = iconName?.let { ctx.resources.getIdentifier(it, "drawable", ctx.packageName) } ?: 0
                if (resId != 0) Icon.createWithResource(ctx, resId)
                else Icon.createWithResource(ctx, android.R.drawable.ic_menu_help)
            }

            val intent = Intent(ACTION_PIP).apply {
                setPackage(ctx.packageName)
                putExtra("id", id)
                val extras = a["extras"]
                if (extras is Map<*, *>) {
                    @Suppress("UNCHECKED_CAST")
                    putExtra("extras", mapToBundle(extras as Map<String, Any?>))
                }
            }
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or
                (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
            val pending = PendingIntent.getBroadcast(ctx, id.hashCode(), intent, flags)

            android.app.RemoteAction(icon, title, title, pending)
        }
    }

    private fun mapToBundle(map: Map<String, Any?>): Bundle {
        val b = Bundle()
        for ((k, v) in map) {
            when (v) {
                null -> b.putString(k, null)
                is Int -> b.putInt(k, v)
                is Long -> b.putLong(k, v)
                is Boolean -> b.putBoolean(k, v)
                is Double -> b.putDouble(k, v)
                is Float -> b.putFloat(k, v)
                is String -> b.putString(k, v)
                else -> b.putString(k, v.toString())
            }
        }
        return b
    }

    private fun bundleToMap(b: Bundle): Map<String, Any?> {
        val m = mutableMapOf<String, Any?>()
        for (key in b.keySet()) {
            m[key] = b.get(key)
        }
        return m
    }

    // ===== Notifications =====

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

    private fun showOngoingNotif(title: String, text: String, route: String?) {
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

        val notif = NotificationCompat.Builder(ctx, NOTIF_CHANNEL)
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
            .setUsesChronometer(true)
            .setContentIntent(pi)
            .build()

        NotificationManagerCompat.from(ctx).notify(NOTIF_ID, notif)
    }

    private fun cancelOngoingNotif() {
        NotificationManagerCompat.from(applicationContext).cancel(NOTIF_ID)
    }

    // ===== Overlay helpers =====

    private fun hasOverlayPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(applicationContext)
        } else true
    }

    private fun requestOverlayPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val intent = Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:${applicationContext.packageName}")
            ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            applicationContext.startActivity(intent)
        }
    }

    private fun dp(dp: Int): Int {
        val dm = applicationContext.resources.displayMetrics
        return (dp * dm.density).toInt()
    }

    private fun statusBarHeight(): Int {
        val resId = applicationContext.resources.getIdentifier("status_bar_height", "dimen", "android")
        return if (resId > 0) applicationContext.resources.getDimensionPixelSize(resId) else 0
    }

    private fun showGlobalBanner(title: String, text: String, route: String?) {
        if (overlayView != null) return
        if (!hasOverlayPermission()) return

        val ctx = applicationContext
        windowManager = ctx.getSystemService(Context.WINDOW_SERVICE) as WindowManager

        val container = LinearLayout(ctx).apply {
            orientation = LinearLayout.HORIZONTAL
            setBackgroundColor(Color.parseColor("#00C853")) // green
            setPadding(dp(12), dp(10), dp(12), dp(10))
            elevation = 8f
        }

        val tv = TextView(ctx).apply {
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
            typeface = Typeface.DEFAULT_BOLD
            this.text = "$title • $text"
        }
        container.addView(tv)

        container.setOnClickListener {
            // Bring app to foreground
            val launch = ctx.packageManager.getLaunchIntentForPackage(ctx.packageName)?.apply {
                addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
                )
                putExtra("from_overlay", true)
                if (route != null) putExtra("route", route)
            }
            if (launch != null) {
                ctx.startActivity(launch)
            }
            // Optional: hide after tap
            hideGlobalBanner()
        }

        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        else
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE

        val lp = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            type,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
            WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            y = statusBarHeight() // just below status bar
        }

        windowManager?.addView(container, lp)
        overlayView = container
    }

    private fun hideGlobalBanner() {
        try {
            overlayView?.let { v ->
                windowManager?.removeView(v)
            }
        } catch (_: Exception) {}
        overlayView = null
    }


    private fun startOngoingCallChip(title: String, text: String, route: String, startMs: Long) {
    val ctx = applicationContext
    val i = Intent(ctx, OngoingCallService::class.java).apply {
        putExtra("title", title)
        putExtra("text", text)
        putExtra("route", route)
        putExtra("startMs", startMs)
      }
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
          ctx.startForegroundService(i)
      } else {
          ctx.startService(i)
      }
    }

  private fun stopOngoingCallChip() {
      applicationContext.stopService(Intent(applicationContext, OngoingCallService::class.java))
  }
}