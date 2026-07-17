package com.misync.finance

import android.content.Context
import android.util.Log
import kotlinx.coroutines.MainScope
import kotlinx.coroutines.launch
import androidx.glance.appwidget.updateAll

class InvestmentsManager(private val context: Context) {
    private val TAG = "InvestmentsManager"

    fun updateWidget() {
        Log.d(TAG, "updateWidget called, launching Glance updateAll")
        MainScope().launch {
            try {
                InvestmentsWidget().updateAll(context)
                Log.d(TAG, "Glance updateAll completed successfully")
            } catch (e: Exception) {
                Log.e(TAG, "Error updating Glance widget: ", e)
            }
        }
    }
}
