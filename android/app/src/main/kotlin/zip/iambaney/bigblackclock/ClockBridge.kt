package zip.iambaney.bigblackclock

import android.Manifest
import android.app.Activity
import android.app.AlarmManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.BatteryManager
import android.os.Build
import android.os.Debug
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import android.view.WindowManager
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.concurrent.Executors
import kotlin.concurrent.thread
import kotlin.math.ln
import kotlin.math.roundToInt

/**
 * The Android side of lib/platform/clock_platform.dart. The only permission
 * it uses is the optional DUMP grant described at [nextRealAlarm]; the
 * battery broadcast needs none.
 */
class ClockBridge(private val activity: Activity, messenger: BinaryMessenger) {
    private val sensors = activity.getSystemService(Context.SENSOR_SERVICE) as SensorManager
    private val alarms = activity.getSystemService(Context.ALARM_SERVICE) as AlarmManager
    private val lightSensor: Sensor? = sensors.getDefaultSensor(Sensor.TYPE_LIGHT)
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    init {
        MethodChannel(messenger, "$PREFIX/platform").setMethodCallHandler { call, result ->
            when (call.method) {
                "capabilities" -> result.success(
                    mapOf("ambientLight" to (lightSensor != null), "nextAlarm" to true, "battery" to true)
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
            private var sink: EventChannel.EventSink? = null

            override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                sink = events
                // Reading the full alarm list takes a moment, so it runs off
                // the main thread.
                val send = {
                    worker.execute {
                        val next = nextRealAlarm()
                        main.post { sink?.success(next) }
                    }
                }
                val filter = IntentFilter(AlarmManager.ACTION_NEXT_ALARM_CLOCK_CHANGED)
                receiver = object : BroadcastReceiver() {
                    override fun onReceive(context: Context, intent: Intent) = send()
                }.also { register(it, filter) }
                send()
            }

            override fun onCancel(arguments: Any?) {
                receiver?.let(activity::unregisterReceiver)
                receiver = null
                sink = null
            }
        })

        // The system re-broadcasts the battery state every few seconds while
        // charging; only a new percentage or a charger change is sent on.
        EventChannel(messenger, "$PREFIX/battery").setStreamHandler(object : EventChannel.StreamHandler {
            private var receiver: BroadcastReceiver? = null

            override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                receiver = object : BroadcastReceiver() {
                    private var last: Map<String, Any>? = null

                    override fun onReceive(context: Context, intent: Intent) {
                        val level = intent.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
                        val scale = intent.getIntExtra(BatteryManager.EXTRA_SCALE, -1)
                        if (level < 0 || scale <= 0) return
                        val state = mapOf(
                            "percent" to (level * 100f / scale).roundToInt(),
                            // Plugged in, as the status bar's bolt means it: a
                            // full battery, or one Samsung holds at 85% to
                            // protect it, still counts.
                            "charging" to (intent.getIntExtra(BatteryManager.EXTRA_PLUGGED, 0) != 0),
                        )
                        if (state == last) return
                        last = state
                        events.success(state)
                    }
                }.also {
                    // A sticky broadcast: registering delivers the current state at once.
                    register(it, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
                }
            }

            override fun onCancel(arguments: Any?) {
                receiver?.let(activity::unregisterReceiver)
                receiver = null
            }
        })
    }

    /** For system broadcasts, which still reach a receiver closed to other apps. */
    private fun register(receiver: BroadcastReceiver, filter: IntentFilter) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            activity.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            activity.registerReceiver(receiver, filter)
        }
    }

    /**
     * The next real alarm. Some apps use setAlarmClock for background timers
     * because it survives Doze (Samsung Find My Mobile re-arms one about two
     * hours ahead all day, and Samsung Clock registers its bedtime and wake-up
     * reminders the same way). Those attach a broadcast as the "show" intent;
     * real alarms attach an activity that opens the alarm screen.
     *
     * AlarmManager reports only the earliest alarm clock, which on such a
     * phone is nearly always a fake. With DUMP and usage access (both granted
     * once over adb; see AndroidManifest.xml) the whole list can be read and
     * the earliest real alarm picked.
     * Without it, or if the list cannot be parsed, the earliest entry is used
     * only when it is real. Android 11 and older cannot tell the two apart, so
     * everything passes there.
     */
    private fun nextRealAlarm(): Long? {
        val info = alarms.nextAlarmClock ?: return null
        if (activity.checkSelfPermission(Manifest.permission.DUMP) == PackageManager.PERMISSION_GRANTED) {
            dumpedAlarmClocks()?.let { clocks ->
                val now = System.currentTimeMillis()
                return clocks.filter { it.opensActivity && it.time > now }.minOfOrNull { it.time }
            }
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && info.showIntent?.isActivity != true) return null
        return info.triggerTime
    }

    private class AlarmClockEntry(val time: Long, val opensActivity: Boolean)

    /**
     * Every alarm clock in the system's alarm dump, or null if the dump could
     * not be read or no entry in it was recognized. The entries look like:
     *
     *     RTC_WAKEUP #94: Alarm{d62709c type 0 origWhen 1794844800000 whenElapsed 821778061 com.sec.android.app.clockpackage}
     *       ...
     *       Alarm clock:
     *         triggerTime=2026-11-16 08:00:00.000
     *         showIntent=PendingIntent{5e1aaa5: PendingIntentRecord{ca40446 com.sec.android.app.clockpackage startActivity}}
     */
    private fun dumpedAlarmClocks(): List<AlarmClockEntry>? {
        val text = dump("alarm") ?: return null
        val header = Regex("""Alarm\{\w+ type \d+ origWhen (\d+) """)
        val entries = mutableListOf<AlarmClockEntry>()
        var time: Long? = null
        var inAlarmClock = false
        for (line in text.lineSequence()) {
            val match = header.find(line)
            if (match != null) {
                time = match.groupValues[1].toLong()
                inAlarmClock = false
                continue
            }
            val trimmed = line.trim()
            if (trimmed == "Alarm clock:") {
                inAlarmClock = true
            } else if (inAlarmClock && trimmed.startsWith("showIntent=")) {
                time?.let { entries += AlarmClockEntry(it, trimmed.contains(" startActivit")) }
                inAlarmClock = false
            }
        }
        return entries.ifEmpty { null }
    }

    /** A system service's debug dump as text. Needs the DUMP permission. */
    private fun dump(service: String): String? {
        val (read, write) = ParcelFileDescriptor.createPipe()
        val output = ByteArrayOutputStream()
        // Drain the pipe while the service writes, or a large dump would block.
        val reader = thread { ParcelFileDescriptor.AutoCloseInputStream(read).use { it.copyTo(output) } }
        val ok = write.use { Debug.dumpService(service, it.fileDescriptor, arrayOf()) }
        reader.join(5_000)
        return if (ok) output.toString() else null
    }

    companion object {
        private const val PREFIX = "zip.iambaney.bigblackclock"

        /** Lux to 0..1 on a log scale: 0 lux is 0, 10,000 lux and above is 1. */
        fun normalize(lux: Float): Double = (ln(lux.toDouble() + 1) / ln(10_001.0)).coerceIn(0.0, 1.0)
    }
}
