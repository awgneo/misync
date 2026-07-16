package com.misync.finance

import android.content.Intent
import android.widget.RemoteViewsService

class InvestmentsWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return InvestmentsWidgetFactory(this.applicationContext, intent)
    }
}
