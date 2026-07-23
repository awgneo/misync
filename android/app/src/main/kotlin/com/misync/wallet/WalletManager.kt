package com.misync.wallet

import android.content.Context
import android.net.Uri
import android.util.Log
import java.io.BufferedReader
import java.io.InputStreamReader
import java.util.zip.ZipInputStream

class WalletManager(private val context: Context) {
    private val TAG = "WalletManager"

    fun processPkpassUri(uriString: String): Map<String, Any>? {
        Log.d(TAG, "Processing pkpass URI: $uriString")
        try {
            val uri = Uri.parse(uriString)
            val scheme = uri.scheme
            val inputStream = if (scheme == "http" || scheme == "https") {
                val url = java.net.URL(uriString)
                val conn = url.openConnection() as java.net.HttpURLConnection
                conn.connectTimeout = 15000
                conn.readTimeout = 15000
                conn.instanceFollowRedirects = true
                val responseCode = conn.responseCode
                if (responseCode !in 200..299) {
                    Log.e(TAG, "Failed to download pkpass from HTTP. Response code: $responseCode")
                    return null
                }
                conn.inputStream
            } else {
                context.contentResolver.openInputStream(uri)
            } ?: return null
            val zipInputStream = ZipInputStream(inputStream)
            var entry = zipInputStream.nextEntry
            var passJsonString: String? = null

            while (entry != null) {
                if (entry.name == "pass.json") {
                    val reader = BufferedReader(InputStreamReader(zipInputStream))
                    val builder = StringBuilder()
                    var line = reader.readLine()
                    while (line != null) {
                        builder.append(line)
                        line = reader.readLine()
                    }
                    passJsonString = builder.toString()
                    break
                }
                entry = zipInputStream.nextEntry
            }
            zipInputStream.close()

            if (passJsonString == null) {
                Log.e(TAG, "pass.json not found in pkpass file")
                return null
            }

            return mapOf("passJson" to passJsonString)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to process pkpass file: ", e)
            return null
        }
    }
}
