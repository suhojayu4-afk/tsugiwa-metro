package jp.tsugiwa.tsugiwa_metro

import android.content.Context

/**
 * Today's information for both home screen widgets (MY駅 and 地下鉄案内),
 * sent by the app over "tsugiwa/widget" ("info"). All texts arrive
 * localized from Dart (lib/platform/home_widget_bridge.dart).
 */
object WidgetInfo {
    private const val PREFS = "widget_info"

    data class Info(
        val weather: String,
        val rain: String,
        val wet: Boolean,
        val route: String,
        val line: String,
        val lineColor: Int,
        val lastLabel: String,
        val lastTime: String,
        val firstLabel: String,
        val firstTime: String,
        val alarm: Boolean,
        // つぎの電車: ride time, "約%d分おき", 運行終了 text, service window
        // (service minutes; -1 = no timetable) and the interval per clock hour.
        val tripText: String,
        val everyFormat: String,
        val endedText: String,
        val firstMin: Int,
        val lastMin: Int,
        val headways: List<Int>,
    ) {
        val hasRoute get() = route.isNotEmpty()
    }

    fun save(context: Context, m: Map<String, Any?>) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().apply {
            for (k in listOf(
                "weather", "rain", "route", "line", "lastLabel", "lastTime", "firstLabel", "firstTime",
                "tripText", "everyFormat", "endedText",
            )) {
                putString(k, m[k] as? String ?: "")
            }
            putInt("lineColor", (m["lineColor"] as? Number)?.toInt() ?: 0xFF80C241.toInt())
            putBoolean("wet", m["wet"] == true)
            putBoolean("alarm", m["alarm"] == true)
            putInt("firstMin", (m["firstMin"] as? Number)?.toInt() ?: -1)
            putInt("lastMin", (m["lastMin"] as? Number)?.toInt() ?: -1)
            putString("headways", (m["headways"] as? List<*>)?.joinToString(",") { "${(it as? Number)?.toInt() ?: 0}" } ?: "")
        }.apply()
        NextWidget.refresh(context)
        MyStationWidget.refresh(context)
        BoardWidget.refresh(context)
    }

    fun load(context: Context): Info {
        val p = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        fun s(k: String) = p.getString(k, "") ?: ""
        return Info(
            weather = s("weather"),
            rain = s("rain"),
            wet = p.getBoolean("wet", false),
            route = s("route"),
            line = s("line"),
            lineColor = p.getInt("lineColor", 0xFF80C241.toInt()),
            lastLabel = s("lastLabel"),
            lastTime = s("lastTime"),
            firstLabel = s("firstLabel"),
            firstTime = s("firstTime"),
            alarm = p.getBoolean("alarm", false),
            tripText = s("tripText"),
            everyFormat = s("everyFormat"),
            endedText = s("endedText"),
            firstMin = p.getInt("firstMin", -1),
            lastMin = p.getInt("lastMin", -1),
            headways = s("headways").split(",").mapNotNull { it.toIntOrNull() },
        )
    }
}
