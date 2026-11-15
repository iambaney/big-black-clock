package zip.iambaney.bigblackclock

import android.app.Activity
import android.app.AlarmManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.view.WindowManager
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlin.math.ln

/** The Android side of lib/platform/clock_platform.dart. Needs no permissions. */
class ClockBridge(private val activity: Activity, messenger: BinaryMessenger) {
    private val sensors = activity.getSystemService(Context.SENSOR_SERVICE) as SensorManager
    private val alarms = activity.getSystemService(Context.ALARM_SERVICE) as AlarmManager
    private val lightSensor: Sensor? = sensors.getDefaultSensor(Sensor.TYPE_LIGHT)

    init {
        MethodChannel(messenger, "$PREFIX/platform").setMethodCallHandler { call, result ->
            when (call.method) {
                "capabilities" -> result.success(
                    mapOf("ambientLight" to (lightSensor != null), "nextAlarm" to true)
                )
                "setBrightness" -> {
                    // Affects only this window, and only while it is in the foreground.
                    val level = call.arguments as Double?
                    activity.window.attributes = activity.window.attributes.apply {
                        screenBrightness = level?.toFloat() ?: WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(messenger, "$PREFIX/ambient").setStreamHandler(object : EventChannel.StreamHandler {
            private var listener: SensorEventListener? = null

            override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                val sensor = lightSensor ?: return events.endOfStream()
                listener = object : SensorEventListener {
                    override fun onSensorChanged(event: SensorEvent) = events.success(normalize(event.values[0]))
                    override fun onAccuracyChanged(sensor: Sensor, accuracy: Int) {}
                }.also { sensors.registerListener(it, sensor, SensorManager.SENSOR_DELAY_NORMAL) }
            }

            override fun onCancel(arguments: Any?) {
                listener?.let(sensors::unregisterListener)
                listener = null
            }
        })

        // AlarmManager.getNextAlarmClock is what the lock screen uses. Do not
        // use Settings.System.NEXT_ALARM_FORMATTED, which modern clock apps no
        // longer keep up to date.
        EventChannel(messenger, "$PREFIX/alarm").setStreamHandler(object : EventChannel.StreamHandler {
            private var receiver: BroadcastReceiver? = null

            override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                val send = { events.success(alarms.nextAlarmClock?.triggerTime) }
                val filter = IntentFilter(AlarmManager.ACTION_NEXT_ALARM_CLOCK_CHANGED)
                receiver = object : BroadcastReceiver() {
                    override fun onReceive(context: Context, intent: Intent) = send()
                }.also {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        activity.registerReceiver(it, filter, Context.RECEIVER_NOT_EXPORTED)
                    } else {
                        activity.registerReceiver(it, filter)
                    }
                }
                send()
            }

            override fun onCancel(arguments: Any?) {
                receiver?.let(activity::unregisterReceiver)
                receiver = null
            }
        })
    }

    companion object {
        private const val PREFIX = "zip.iambaney.bigblackclock"

        /** Lux to 0..1 on a log scale: 0 lux is 0, 10,000 lux and above is 1. */
        fun normalize(lux: Float): Double = (ln(lux.toDouble() + 1) / ln(10_001.0)).coerceIn(0.0, 1.0)
    }
}
