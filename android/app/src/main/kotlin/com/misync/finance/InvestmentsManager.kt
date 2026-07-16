package com.misync.finance

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.util.Log

class InvestmentsManager(private val context: Context) {
    private val TAG = "InvestmentsManager"

    fun updateWidget() {
        Log.d(TAG, "updateWidget called, broadcasting UPDATE intent")
        val appWidgetManager = AppWidgetManager.getInstance(context)
        val componentName = ComponentName(context, InvestmentsWidgetProvider::class.java)
        val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)

        val intent = Intent(context, InvestmentsWidgetProvider::class.java).apply {
            action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, appWidgetIds)
        }
        context.sendBroadcast(intent)
        
        // Notify both the ViewPager and inner ListView adapters of data changes
        if (appWidgetIds.isNotEmpty()) {
            val viewPagerId = context.resources.getIdentifier("watchlists_viewpager", "id", context.packageName)
            if (viewPagerId != 0) {
                appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetIds, viewPagerId)
            }
            
            val listViewId = context.resources.getIdentifier("watchlist_list", "id", context.packageName)
            if (listViewId != 0) {
                appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetIds, listViewId)
            }
        }
    }
}
