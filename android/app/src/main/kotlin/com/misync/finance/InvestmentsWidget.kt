package com.misync.finance

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.lazy.LazyColumn
import androidx.glance.appwidget.lazy.items
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.layout.*
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.text.TextAlign
import androidx.glance.unit.ColorProvider
import org.json.JSONArray
import org.json.JSONObject
import androidx.compose.ui.graphics.Color
import androidx.glance.action.clickable
import androidx.glance.action.ActionParameters
import androidx.glance.appwidget.action.ActionCallback
import androidx.glance.appwidget.action.actionRunCallback
import androidx.glance.appwidget.state.updateAppWidgetState
import androidx.glance.state.PreferencesGlanceStateDefinition
import androidx.glance.currentState
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.intPreferencesKey
import android.graphics.Color as AndroidColor

class InvestmentsWidget : GlanceAppWidget() {
    override val stateDefinition = PreferencesGlanceStateDefinition

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent {
            GlanceContent(context)
        }
    }

    @Composable
    private fun GlanceContent(context: Context) {
        val watchlists = loadWatchlists(context)
        
        Column(
            modifier = GlanceModifier
                .fillMaxSize()
                .background(ColorProvider(Color(0xFF0F1219)))
                .padding(8.dp)
        ) {
            if (watchlists.length() == 0) {
                Box(
                    modifier = GlanceModifier.fillMaxSize(),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = "No watchlist data. Please enable sync & enter credentials.",
                        style = TextStyle(
                            color = ColorProvider(Color(0xFF888888)),
                            fontSize = 12.sp
                        )
                    )
                }
            } else {
                val glancePrefs = currentState<Preferences>()
                val currentIndex = glancePrefs[intPreferencesKey("widget_watchlist_index")] ?: 0
                val index = if (currentIndex < 0 || currentIndex >= watchlists.length()) 0 else currentIndex
                android.util.Log.d("InvestmentsWidget", "GlanceContent: currentIndex=$currentIndex, resolved index=$index, name=${watchlists.getJSONObject(index).optString("name")}")
                
                val watchlist = watchlists.getJSONObject(index)
                val name = watchlist.optString("name", "Primary Watchlist")
                val items = watchlist.optJSONArray("items") ?: JSONArray()
                
                Row(
                    modifier = GlanceModifier
                        .fillMaxWidth()
                        .padding(start = 8.dp, end = 8.dp, top = 4.dp, bottom = 8.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = name,
                        style = TextStyle(
                            color = ColorProvider(Color(0xFF00E5FF)),
                            fontSize = 14.sp,
                            fontWeight = FontWeight.Bold
                        ),
                        modifier = GlanceModifier.defaultWeight()
                    )
                    
                    Row(
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        if (index > 0) {
                            Text(
                                text = "◀",
                                style = TextStyle(
                                    color = ColorProvider(Color(0xFF00E5FF)),
                                    fontSize = 14.sp,
                                    fontWeight = FontWeight.Bold
                                ),
                                modifier = GlanceModifier
                                    .clickable(actionRunCallback<PrevWatchlistAction>())
                                    .padding(horizontal = 8.dp)
                            )
                        }
                        
                        if (index < watchlists.length() - 1) {
                            Text(
                                text = "▶",
                                style = TextStyle(
                                    color = ColorProvider(Color(0xFF00E5FF)),
                                    fontSize = 14.sp,
                                    fontWeight = FontWeight.Bold
                                  ),
                                modifier = GlanceModifier
                                    .clickable(actionRunCallback<NextWatchlistAction>())
                                    .padding(start = 8.dp)
                            )
                        }
                    }
                }
                
                Spacer(
                    modifier = GlanceModifier
                        .fillMaxWidth()
                        .height(1.dp)
                        .background(ColorProvider(Color(0xFF26324D)))
                )
                
                if (items.length() == 0) {
                    Box(
                        modifier = GlanceModifier.fillMaxSize(),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            text = "No investments in this watchlist",
                            style = TextStyle(
                                color = ColorProvider(Color(0xFF888888)),
                                fontSize = 12.sp
                            )
                        )
                    }
                } else {
                    LazyColumn(
                        modifier = GlanceModifier.fillMaxSize()
                    ) {
                        val listSize = minOf(items.length(), 5)
                        items((0 until listSize).toList()) { index ->
                            val stock = items.getJSONObject(index)
                            val symbol = stock.optString("symbol", "")
                            val price = stock.optDouble("price", 0.0)
                            val change = stock.optDouble("change", 0.0)
                            
                            Column(
                                modifier = GlanceModifier.fillMaxWidth()
                            ) {
                                Row(
                                    modifier = GlanceModifier
                                        .fillMaxWidth()
                                        .height(32.dp)
                                        .padding(start = 8.dp, end = 8.dp),
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Text(
                                        text = symbol,
                                        style = TextStyle(
                                            color = ColorProvider(Color.White),
                                            fontSize = 12.sp,
                                            fontWeight = FontWeight.Bold
                                        ),
                                        modifier = GlanceModifier.defaultWeight()
                                    )
                                    
                                    Text(
                                        text = "$${String.format("%.2f", price)}",
                                        style = TextStyle(
                                            color = ColorProvider(Color.White),
                                            fontSize = 12.sp
                                        ),
                                        modifier = GlanceModifier.padding(end = 8.dp)
                                    )
                                    
                                    val changeSign = if (change >= 0.0) "+" else ""
                                    val changeColor = if (change >= 0.0) "#00E676" else "#FF1744"
                                    Text(
                                        text = "$changeSign${String.format("%.2f", change)}%",
                                        style = TextStyle(
                                            color = ColorProvider(Color(AndroidColor.parseColor(changeColor))),
                                            fontSize = 12.sp,
                                            fontWeight = FontWeight.Bold,
                                            textAlign = TextAlign.End
                                        ),
                                        modifier = GlanceModifier.width(60.dp)
                                    )
                                }
                                
                                if (index < listSize - 1) {
                                    Spacer(
                                        modifier = GlanceModifier
                                            .fillMaxWidth()
                                            .height(0.5.dp)
                                            .background(ColorProvider(Color(0xFF1C2230)))
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private fun loadWatchlists(context: Context): JSONArray {
        try {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val financeJsonStr = prefs.getString("flutter.misync.finance.finance", "")
            if (!financeJsonStr.isNullOrEmpty()) {
                val finance = JSONObject(financeJsonStr)
                val sources = finance.optJSONObject("sources")
                if (sources != null && sources.optString("investments", "none") != "none") {
                    val investmentsJsonStr = prefs.getString("flutter.misync.finance.investments", "")
                    if (!investmentsJsonStr.isNullOrEmpty()) {
                        val investments = JSONObject(investmentsJsonStr)
                        return investments.optJSONArray("watchlists") ?: JSONArray()
                    }
                }
            }
        } catch (e: Exception) {
            // handle error safely
        }
        return JSONArray()
    }
}

class PrevWatchlistAction : ActionCallback {
    override suspend fun onAction(
        context: Context,
        glanceId: GlanceId,
        parameters: ActionParameters
    ) {
        android.util.Log.d("InvestmentsWidget", "PrevWatchlistAction.onAction triggered")
        
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val investmentsJsonStr = prefs.getString("flutter.misync.finance.investments", "")
        var total = 0
        if (!investmentsJsonStr.isNullOrEmpty()) {
            try {
                val investments = JSONObject(investmentsJsonStr)
                val watchlistsArray = investments.optJSONArray("watchlists")
                if (watchlistsArray != null) {
                    total = watchlistsArray.length()
                }
            } catch (_: Exception) {}
        }
        
        if (total > 0) {
            var updated = false
            updateAppWidgetState(context, PreferencesGlanceStateDefinition, glanceId) { statePrefs ->
                val currentIndex = statePrefs[intPreferencesKey("widget_watchlist_index")] ?: 0
                if (currentIndex > 0) {
                    val prevIndex = currentIndex - 1
                    android.util.Log.d("InvestmentsWidget", "PrevWatchlistAction: total=$total, currentIndex=$currentIndex, prevIndex=$prevIndex")
                    updated = true
                    statePrefs.toMutablePreferences().apply {
                        this[intPreferencesKey("widget_watchlist_index")] = prevIndex
                    }
                } else {
                    statePrefs
                }
            }
            if (updated) {
                InvestmentsWidget().update(context, glanceId)
            }
        }
    }
}

class NextWatchlistAction : ActionCallback {
    override suspend fun onAction(
        context: Context,
        glanceId: GlanceId,
        parameters: ActionParameters
    ) {
        android.util.Log.d("InvestmentsWidget", "NextWatchlistAction.onAction triggered")
        
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val investmentsJsonStr = prefs.getString("flutter.misync.finance.investments", "")
        var total = 0
        if (!investmentsJsonStr.isNullOrEmpty()) {
            try {
                val investments = JSONObject(investmentsJsonStr)
                val watchlistsArray = investments.optJSONArray("watchlists")
                if (watchlistsArray != null) {
                    total = watchlistsArray.length()
                }
            } catch (_: Exception) {}
        }
        
        if (total > 0) {
            var updated = false
            updateAppWidgetState(context, PreferencesGlanceStateDefinition, glanceId) { statePrefs ->
                val currentIndex = statePrefs[intPreferencesKey("widget_watchlist_index")] ?: 0
                if (currentIndex < total - 1) {
                    val nextIndex = currentIndex + 1
                    android.util.Log.d("InvestmentsWidget", "NextWatchlistAction: total=$total, currentIndex=$currentIndex, nextIndex=$nextIndex")
                    updated = true
                    statePrefs.toMutablePreferences().apply {
                        this[intPreferencesKey("widget_watchlist_index")] = nextIndex
                    }
                } else {
                    statePrefs
                }
            }
            if (updated) {
                InvestmentsWidget().update(context, glanceId)
            }
        }
    }
}
