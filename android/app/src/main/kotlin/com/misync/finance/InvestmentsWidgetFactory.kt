package com.misync.finance

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import org.json.JSONArray
import org.json.JSONObject

class InvestmentsWidgetFactory(
    private val context: Context,
    intent: Intent
) : RemoteViewsService.RemoteViewsFactory {
    private val TAG = "InvestmentsWidgetFact"
    private var watchlists = JSONArray()
    private val appWidgetId = intent.getIntExtra(
        AppWidgetManager.EXTRA_APPWIDGET_ID,
        AppWidgetManager.INVALID_APPWIDGET_ID
    )

    override fun onCreate() {
        loadData()
    }

    override fun onDataSetChanged() {
        loadData()
    }

    private fun loadData() {
        Log.d(TAG, "loadData called")
        try {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            
            Log.d(TAG, "All Prefs keys: ${prefs.all.keys.joinToString(", ")}")
            
            // 1. Check if investments are enabled in Finance settings
            val financeJsonStr = prefs.getString("flutter.misync.finance.finance", "")
            Log.d(TAG, "financeJsonStr: $financeJsonStr")
            var enabled = false
            if (!financeJsonStr.isNullOrEmpty()) {
                val finance = JSONObject(financeJsonStr)
                val sources = finance.optJSONObject("sources")
                if (sources != null) {
                    val source = sources.optString("investments", "none")
                    Log.d(TAG, "Investments source: $source")
                    enabled = source != "none"
                }
            }
            
            Log.d(TAG, "enabled: $enabled")
            if (enabled) {
                // 2. Load watchlists from Investments blob
                val investmentsJsonStr = prefs.getString("flutter.misync.finance.investments", "")
                Log.d(TAG, "investmentsJsonStr: $investmentsJsonStr")
                if (!investmentsJsonStr.isNullOrEmpty()) {
                    val investments = JSONObject(investmentsJsonStr)
                    val watchlistsArray = investments.optJSONArray("watchlists")
                    if (watchlistsArray != null) {
                        watchlists = watchlistsArray
                        Log.d(TAG, "Loaded ${watchlists.length()} watchlists from cache")
                        return
                    }
                }
            }
            
            watchlists = JSONArray()
            Log.d(TAG, "No investments enabled or no cached data found")
        } catch (e: Exception) {
            Log.e(TAG, "Error loading cache: ", e)
            watchlists = JSONArray()
        }
    }

    override fun onDestroy() {
        watchlists = JSONArray()
    }

    override fun getCount(): Int {
        return watchlists.length()
    }

    override fun getViewAt(position: Int): RemoteViews {
        val packageName = context.packageName
        val pageLayoutId = context.resources.getIdentifier("investments_widget_page", "layout", packageName)
        
        val views = RemoteViews(packageName, pageLayoutId)
        
        if (position < 0 || position >= watchlists.length()) {
            return views
        }

        try {
            val watchlist = watchlists.getJSONObject(position)
            val name = watchlist.optString("name", "Watchlist")
            val titleId = context.resources.getIdentifier("watchlist_title", "id", packageName)
            if (titleId != 0) {
                views.setTextViewText(titleId, name)
            }

            val investments = watchlist.optJSONArray("items") ?: JSONArray()
            val totalRows = 5

            for (i in 1..totalRows) {
                val rowId = context.resources.getIdentifier("stock_row_$i", "id", packageName)
                val symbolId = context.resources.getIdentifier("stock_symbol_$i", "id", packageName)
                val priceId = context.resources.getIdentifier("stock_price_$i", "id", packageName)
                val changeId = context.resources.getIdentifier("stock_change_$i", "id", packageName)

                if (rowId == 0) continue

                val dataIndex = i - 1
                if (dataIndex < investments.length()) {
                    val stock = investments.getJSONObject(dataIndex)
                    val symbol = stock.optString("symbol", "")
                    val price = stock.optDouble("price", 0.0)
                    val change = stock.optDouble("change", 0.0)

                    if (symbolId != 0) views.setTextViewText(symbolId, symbol)
                    if (priceId != 0) views.setTextViewText(priceId, "$${String.format("%.2f", price)}")
                    
                    if (changeId != 0) {
                        val changeSign = if (change >= 0.0) "+" else ""
                        views.setTextViewText(changeId, "$changeSign${String.format("%.2f", change)}%")
                        if (change >= 0.0) {
                            views.setTextColor(changeId, Color.parseColor("#00E676"))
                        } else {
                            views.setTextColor(changeId, Color.parseColor("#FF1744"))
                        }
                    }
                    views.setViewVisibility(rowId, View.VISIBLE)
                } else {
                    views.setViewVisibility(rowId, View.GONE)
                }
            }

            val emptyStateId = context.resources.getIdentifier("page_empty_view", "id", packageName)
            if (emptyStateId != 0) {
                if (investments.length() == 0) {
                    views.setViewVisibility(emptyStateId, View.VISIBLE)
                } else {
                    views.setViewVisibility(emptyStateId, View.GONE)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error building page RemoteViews at $position: ", e)
        }

        return views
    }

    override fun getLoadingView(): RemoteViews? {
        return null
    }

    override fun getViewTypeCount(): Int {
        return 1
    }

    override fun getItemId(position: Int): Long {
        return position.toLong()
    }

    override fun hasStableIds(): Boolean {
        return true
    }
}
