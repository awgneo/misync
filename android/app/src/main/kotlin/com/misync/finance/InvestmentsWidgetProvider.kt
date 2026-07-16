package com.misync.finance

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.util.Log
import android.widget.RemoteViews

class InvestmentsWidgetProvider : AppWidgetProvider() {
    private val TAG = "InvestmentsWidgetProv"

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        Log.d(TAG, "onUpdate called for ${appWidgetIds.size} widgets")
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        Log.d(TAG, "onReceive action: ${intent.action}")
        
        if (intent.action == "com.misync.investments.REFRESH") {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val componentName = android.content.ComponentName(context, InvestmentsWidgetProvider::class.java)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)
            
            appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetIds, context.resources.getIdentifier("watchlists_viewpager", "id", context.packageName))
        }
    }

    private fun updateAppWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
        val packageName = context.packageName
        
        val widgetLayoutId = context.resources.getIdentifier("investments_widget", "layout", packageName)
        val viewPagerId = context.resources.getIdentifier("watchlists_viewpager", "id", packageName)
        
        if (widgetLayoutId == 0 || viewPagerId == 0) {
            Log.e(TAG, "failed to find layout or view ids")
            return
        }

        val views = RemoteViews(packageName, widgetLayoutId)

        val serviceIntent = Intent(context, InvestmentsWidgetService::class.java).apply {
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
            data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
        }
        views.setRemoteAdapter(viewPagerId, serviceIntent)
        
        val emptyViewId = context.resources.getIdentifier("empty_view", "id", packageName)
        if (emptyViewId != 0) {
            views.setEmptyView(viewPagerId, emptyViewId)
        }

        val refreshIntent = Intent(context, InvestmentsWidgetProvider::class.java).apply {
            action = "com.misync.investments.REFRESH"
        }
        val refreshPendingIntent = PendingIntent.getBroadcast(
            context,
            appWidgetId,
            refreshIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val refreshBtnId = context.resources.getIdentifier("btn_refresh", "id", packageName)
        if (refreshBtnId != 0) {
            views.setOnClickPendingIntent(refreshBtnId, refreshPendingIntent)
        }

        appWidgetManager.updateAppWidget(appWidgetId, views)
    }
}
