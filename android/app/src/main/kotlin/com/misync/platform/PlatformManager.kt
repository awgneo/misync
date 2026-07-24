package com.misync.platform

import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.util.Log
import java.io.ByteArrayOutputStream

class PlatformManager(private val context: Context) {
    private val TAG = "PlatformManager"

    fun getApps(): List<Map<String, Any>> {
        val pm = context.packageManager
        val mainIntent = Intent(Intent.ACTION_MAIN, null).apply {
            addCategory(Intent.CATEGORY_LAUNCHER)
        }
        val resolveInfos = pm.queryIntentActivities(mainIntent, 0)
        val appsMap = mutableMapOf<String, String>()

        for (ri in resolveInfos) {
            val pkg = ri.activityInfo.packageName
            if (pkg == context.packageName) continue
            val label = ri.loadLabel(pm).toString()
            if (!appsMap.containsKey(pkg)) {
                appsMap[pkg] = label
            }
        }

        return appsMap.entries.map { (pkg, name) ->
            mapOf(
                "package" to pkg,
                "name" to name
            )
        }.sortedBy { (it["name"] as String).lowercase() }
    }

    fun getAppIcon(packageName: String, sizePx: Int = 96): ByteArray? {
        return try {
            val pm = context.packageManager
            val drawable = pm.getApplicationIcon(packageName)
            val bitmap = drawableToBitmap(drawable, sizePx, sizePx)
            val stream = ByteArrayOutputStream()
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
            stream.toByteArray()
        } catch (e: Exception) {
            Log.e(TAG, "Error getting app icon for $packageName", e)
            null
        }
    }

    private fun drawableToBitmap(drawable: Drawable, width: Int, height: Int): Bitmap {
        if (drawable is BitmapDrawable && drawable.bitmap != null) {
            return Bitmap.createScaledBitmap(drawable.bitmap, width, height, true)
        }
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        drawable.setBounds(0, 0, canvas.width, canvas.height)
        drawable.draw(canvas)
        return bitmap
    }
}
