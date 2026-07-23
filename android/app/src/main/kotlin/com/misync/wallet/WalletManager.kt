package com.misync.wallet

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.util.Base64
import android.util.Log
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStream
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import java.util.regex.Pattern
import java.util.zip.ZipInputStream

class WalletManager(private val context: Context) {
    private val TAG = "WalletManager"
    private var pendingPassUri: String? = null

    fun handleIntent(intent: Intent, methodChannel: MethodChannel?): Boolean {
        val action = intent.action
        val data = intent.data
        val type = intent.type ?: (data?.let { context.contentResolver.getType(it) })
        val extraText = intent.getStringExtra(Intent.EXTRA_TEXT)

        Log.d(TAG, "handleIntent called: action=$action, data=$data, type=$type, extraText=$extraText")

        var uriToProcess: String? = null

        if (Intent.ACTION_VIEW == action && data != null) {
            val uriString = data.toString()
            if (isPassUriOrType(uriString, type)) {
                uriToProcess = uriString
            }
        } else if (Intent.ACTION_SEND == action) {
            val rawText = extraText?.trim() ?: data?.toString() ?: intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)?.toString()
            if (rawText != null) {
                val extracted = extractUrlFromText(rawText)
                if (extracted != null && (extracted.contains(".pkpass") || extracted.contains("pay.google.com") || extracted.contains("wallet.google.com"))) {
                    uriToProcess = extracted
                }
            }
        }

        if (uriToProcess != null) {
            Log.d(TAG, "Capturing pass URI/Link: $uriToProcess")
            pendingPassUri = uriToProcess
            handlePkpassUri(uriToProcess, methodChannel)
            return true
        }

        return false
    }

    private fun extractUrlFromText(text: String): String? {
        val matcher = Pattern.compile("(https?://\\S+)").matcher(text)
        if (matcher.find()) {
            return matcher.group(1)
        }
        if (text.startsWith("http://") || text.startsWith("https://")) {
            return text
        }
        return null
    }

    fun consumePendingPass(result: MethodChannel.Result) {
        val uri = pendingPassUri
        pendingPassUri = null
        if (uri != null) {
            Thread {
                val parsed = processPkpassUri(uri)
                Handler(Looper.getMainLooper()).post {
                    result.success(parsed)
                }
            }.start()
        } else {
            result.success(null)
        }
    }

    fun processPkpassUri(uriString: String): Map<String, Any>? {
        Log.d(TAG, "Processing pass URI: $uriString")

        if (uriString.contains("pay.google.com") || uriString.contains("wallet.google.com")) {
            return decodeGoogleWalletJwt(uriString)
        }

        try {
            val uri = Uri.parse(uriString)
            val scheme = uri.scheme
            if (scheme == "http" || scheme == "https") {
                val url = URL(uriString)
                val conn = url.openConnection() as HttpURLConnection
                conn.connectTimeout = 15000
                conn.readTimeout = 15000
                conn.instanceFollowRedirects = true
                conn.setRequestProperty("User-Agent", "Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36")
                if (conn.responseCode in 200..299) {
                    return parseZipPkpass(conn.inputStream)
                }
                return null
            } else {
                val inputStream = context.contentResolver.openInputStream(uri) ?: return null
                return parseZipPkpass(inputStream)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to process pass URI: ", e)
            return null
        }
    }

    private fun parseZipPkpass(inputStream: InputStream): Map<String, Any>? {
        try {
            val zipInputStream = ZipInputStream(inputStream)
            var entry = zipInputStream.nextEntry
            var passJsonString: String? = null
            var enStrings: Map<String, String>? = null

            while (entry != null) {
                val name = entry.name.lowercase(Locale.ROOT)
                if (name == "pass.json") {
                    passJsonString = readInputStreamText(zipInputStream)
                } else if (name.endsWith("en.lproj/pass.strings") || name.endsWith("pass.strings")) {
                    enStrings = parseStringsFile(readInputStreamText(zipInputStream))
                }
                entry = zipInputStream.nextEntry
            }
            zipInputStream.close()

            if (passJsonString == null) {
                Log.e(TAG, "pass.json not found in pkpass file")
                return null
            }

            val json = JSONObject(passJsonString)
            return buildUniversalPassMapFromAppleJson(json, enStrings)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to parse zip pkpass: ", e)
            return null
        }
    }

    private fun buildUniversalPassMapFromAppleJson(json: JSONObject, strings: Map<String, String>?): Map<String, Any> {
        val passTypeIdent = json.optString("passTypeIdentifier")
        val serialNumber = json.optString("serialNumber")
        val id = if (passTypeIdent.isNotEmpty() && serialNumber.isNotEmpty()) {
            "${passTypeIdent}_$serialNumber"
        } else if (serialNumber.isNotEmpty()) {
            serialNumber
        } else {
            "pass_${System.currentTimeMillis()}"
        }

        val rawIssuer = json.optString("organizationName", "Pass")
        val issuer = resolveLoc(rawIssuer, strings)

        val bgColor = parseColorToHex(json.optString("backgroundColor", "#111827"))
        val fgColor = parseColorToHex(json.optString("foregroundColor", "#ffffff"))

        // Extract structure fields & pass type
        var passType = "generic"
        var passTypeObj: JSONObject? = null
        val passKeys = arrayOf("boardingPass", "eventTicket", "coupon", "generic", "storeCard")
        for (k in passKeys) {
          if (json.has(k)) {
              passType = k
              passTypeObj = json.optJSONObject(k)
              break
          }
        }

        val fieldsList = mutableListOf<Map<String, String>>()
        if (passTypeObj != null) {
            val fieldArrays = arrayOf("primaryFields", "secondaryFields", "auxiliaryFields", "headerFields")
            for (arrKey in fieldArrays) {
                val arr = passTypeObj.optJSONArray(arrKey)
                if (arr != null) {
                    for (i in 0 until arr.length()) {
                        val item = arr.optJSONObject(i) ?: continue
                        val rawLabel = item.optString("label", "")
                        val rawVal = item.optString("value", "")
                        if (rawVal.isNotEmpty()) {
                            val label = cleanLabel(resolveLoc(rawLabel, strings))
                            val valStr = resolveLoc(rawVal, strings)
                            fieldsList.add(mapOf("label" to label, "value" to valStr))
                        }
                    }
                }
            }
        }

        // Barcode extraction
        var barcodeValue = ""
        var barcodeFormat = "PKBarcodeFormatQR"
        val barcodes = json.optJSONArray("barcodes")
        if (barcodes != null && barcodes.length() > 0) {
            val b = barcodes.optJSONObject(0)
            if (b != null) {
                barcodeValue = b.optString("message", "")
                barcodeFormat = b.optString("format", "PKBarcodeFormatQR")
            }
        } else {
            val b = json.optJSONObject("barcode")
            if (b != null) {
                barcodeValue = b.optString("message", b.optString("value", ""))
                barcodeFormat = b.optString("format", b.optString("type", "PKBarcodeFormatQR"))
            }
        }

        barcodeFormat = when {
            barcodeFormat.contains("AZTEC", ignoreCase = true) -> "PKBarcodeFormatAztec"
            barcodeFormat.contains("PDF417", ignoreCase = true) || barcodeFormat.contains("PDF_417", ignoreCase = true) -> "PKBarcodeFormatPDF417"
            else -> "PKBarcodeFormatQR"
        }

        // Title extraction
        val rawDesc = resolveLoc(json.optString("description", ""), strings)
        val title = sanitizeTitle(rawDesc, issuer, fieldsList)

        val isoFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US).apply {
            timeZone = TimeZone.getTimeZone("UTC")
        }
        val createdAt = isoFormat.format(Date())

        return mapOf(
            "id" to id,
            "issuer" to issuer,
            "title" to title,
            "type" to passType,
            "backgroundColor" to bgColor,
            "foregroundColor" to fgColor,
            "barcodeValue" to barcodeValue,
            "barcodeFormat" to barcodeFormat,
            "fields" to fieldsList,
            "createdAt" to createdAt
        )
    }

    private fun decodeGoogleWalletJwt(url: String): Map<String, Any>? {
        try {
            val token = url.substringAfter("/save/")
            val parts = token.split(".")
            if (parts.size < 2) return null

            val payloadBytes = Base64.decode(parts[1], Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING)
            val jsonString = String(payloadBytes, Charsets.UTF_8)
            Log.d(TAG, "Decoded Google Wallet JWT payload: $jsonString")

            val json = JSONObject(jsonString)
            val payload = json.optJSONObject("payload") ?: return null

            var passType = "generic"
            var obj: JSONObject? = null

            val gKeys = arrayOf("flightObjects", "loyaltyObjects", "genericObjects", "eventTicketObjects")
            for (gKey in gKeys) {
                val arr = payload.optJSONArray(gKey)
                if (arr != null && arr.length() > 0) {
                    obj = arr.optJSONObject(0)
                    passType = when (gKey) {
                        "flightObjects" -> "boardingPass"
                        "eventTicketObjects" -> "eventTicket"
                        "loyaltyObjects" -> "storeCard"
                        else -> "generic"
                    }
                    break
                }
            }

            if (obj == null) return null

            val id = obj.optString("id", "google_pass_${System.currentTimeMillis()}")
            val issuer = obj.optString("issuerName", "Pass")

            val fieldsList = mutableListOf<Map<String, String>>()
            val textModules = obj.optJSONArray("textModulesData")
            if (textModules != null) {
                for (i in 0 until textModules.length()) {
                    val tm = textModules.optJSONObject(i) ?: continue
                    val header = tm.optString("header", "")
                    val body = tm.optString("body", "")
                    if (body.isNotEmpty()) {
                        fieldsList.add(mapOf("label" to cleanLabel(header), "value" to body))
                    }
                }
            }

            var barcodeValue = ""
            var barcodeFormat = "PKBarcodeFormatQR"
            val b = obj.optJSONObject("barcode")
            if (b != null) {
                barcodeValue = b.optString("value", b.optString("message", ""))
                barcodeFormat = b.optString("type", b.optString("format", "PKBarcodeFormatQR"))
            }

            val bgColor = parseColorToHex(obj.optString("hexBackgroundColor", "#111827"))
            val title = sanitizeTitle(obj.optString("cardTitle", ""), issuer, fieldsList)

            val isoFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US).apply {
                timeZone = TimeZone.getTimeZone("UTC")
            }
            val createdAt = isoFormat.format(Date())

            return mapOf(
                "id" to id,
                "issuer" to issuer,
                "title" to title,
                "type" to passType,
                "backgroundColor" to bgColor,
                "foregroundColor" to "#ffffff",
                "barcodeValue" to barcodeValue,
                "barcodeFormat" to barcodeFormat,
                "fields" to fieldsList,
                "createdAt" to createdAt
            )
        } catch (e: Exception) {
            Log.e(TAG, "Failed to decode Google Wallet JWT URL: $url", e)
            return null
        }
    }

    private fun readInputStreamText(inputStream: InputStream): String {
        val reader = BufferedReader(InputStreamReader(inputStream, Charsets.UTF_8))
        val builder = StringBuilder()
        var line = reader.readLine()
        while (line != null) {
            builder.append(line).append("\n")
            line = reader.readLine()
        }
        return builder.toString()
    }

    private fun parseStringsFile(content: String): Map<String, String> {
        val map = mutableMapOf<String, String>()
        val regex = Pattern.compile("\"([^\"]+)\"\\s*=\\s*\"([^\"]+)\";").matcher(content)
        while (regex.find()) {
            val key = regex.group(1)
            val valStr = regex.group(2)
            if (key != null && valStr != null) {
                map[key] = valStr
            }
        }
        return map
    }

    private fun resolveLoc(text: String, strings: Map<String, String>?): String {
        if (strings == null || text.isBlank()) return text
        return strings[text.trim()] ?: text
    }

    private fun cleanLabel(rawLabel: String): String {
        val trimmed = rawLabel.trim()
        if (trimmed.isEmpty()) return "INFO"

        var label = trimmed.replace(Regex("(Heading|heading|Label|label|Text|text)$"), "").trim()
        if (label.isEmpty()) label = trimmed

        label = label.replace(Regex("(?<=[a-z])(?=[A-Z])"), " ")
        label = label.replace(Regex("[_]+"), " ").trim()

        return label.split(" ").joinToString(" ") { w ->
            if (w.isEmpty()) "" else w.substring(0, 1).uppercase(Locale.ROOT) + w.substring(1).lowercase(Locale.ROOT)
        }
    }

    private fun sanitizeTitle(rawTitle: String, issuer: String, fields: List<Map<String, String>>): String {
        val trimmed = rawTitle.trim()
        if (trimmed.isNotEmpty() && !trimmed.equals("description", ignoreCase = true) && !trimmed.equals("title", ignoreCase = true)) {
            return trimmed
        }
        if (fields.isNotEmpty()) {
            val parts = mutableListOf<String>()
            for (f in fields) {
                val label = f["label"] ?: ""
                val valStr = f["value"] ?: ""
                if (parts.size < 3 && valStr.isNotEmpty()) {
                    if (label.isNotEmpty() && label != "INFO" && !valStr.lowercase(Locale.ROOT).contains(label.lowercase(Locale.ROOT))) {
                        parts.add("$label $valStr")
                    } else {
                        parts.add(valStr)
                    }
                }
            }
            if (parts.isNotEmpty()) return parts.joinToString(" • ")
        }
        return issuer
    }

    private fun parseColorToHex(raw: String): String {
        val str = raw.trim().lowercase(Locale.ROOT)
        if (str.isEmpty()) return "#111827"
        if (str.startsWith("#")) return str

        val rgbMatch = Pattern.compile("rgb\\(\\s*(\\d+)\\s*,\\s*(\\d+)\\s*,\\s*(\\d+)\\s*\\)").matcher(str)
        if (rgbMatch.find()) {
            val r = rgbMatch.group(1)?.toIntOrNull() ?: 17
            val g = rgbMatch.group(2)?.toIntOrNull() ?: 24
            val b = rgbMatch.group(3)?.toIntOrNull() ?: 39
            return String.format("#%02x%02x%02x", r, g, b)
        }
        return str
    }

    private fun handlePkpassUri(uriString: String, methodChannel: MethodChannel?) {
        Thread {
            val parsed = processPkpassUri(uriString)
            Handler(Looper.getMainLooper()).post {
                if (parsed != null) {
                    Log.d(TAG, "Successfully parsed pass in Kotlin. Dispatching Universal Pass Map to Flutter: $parsed")
                    methodChannel?.invokeMethod("passIntercepted", parsed)
                    if (uriString.contains(".pkpass")) {
                        forwardToGoogleWallet(uriString)
                    }
                } else {
                    Log.e(TAG, "Failed to parse pass URI: $uriString")
                }
            }
        }.start()
    }

    private fun forwardToGoogleWallet(uriString: String) {
        try {
            val uri = Uri.parse(uriString)
            val baseIntent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "application/vnd.apple.pkpass")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }

            val pm = context.packageManager
            val resolveInfos = pm.queryIntentActivities(baseIntent, 0)

            val targetIntents = mutableListOf<Intent>()
            var googleWalletIntent: Intent? = null

            for (info in resolveInfos) {
                val pkgName = info.activityInfo.packageName
                if (pkgName != context.packageName) {
                    val target = Intent(baseIntent).apply {
                        setPackage(pkgName)
                    }
                    if (pkgName.contains("wallet") || pkgName.contains("pay")) {
                        googleWalletIntent = target
                    } else {
                        targetIntents.add(target)
                    }
                }
            }

            val chooserIntent: Intent? = when {
                googleWalletIntent != null -> {
                    Intent.createChooser(googleWalletIntent, "Open with Wallet").apply {
                        if (targetIntents.isNotEmpty()) {
                            putExtra(Intent.EXTRA_INITIAL_INTENTS, targetIntents.toTypedArray())
                        }
                    }
                }
                targetIntents.isNotEmpty() -> {
                    val first = targetIntents.removeAt(0)
                    Intent.createChooser(first, "Open with").apply {
                        if (targetIntents.isNotEmpty()) {
                            putExtra(Intent.EXTRA_INITIAL_INTENTS, targetIntents.toTypedArray())
                        }
                    }
                }
                else -> null
            }

            if (chooserIntent != null) {
                chooserIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                context.startActivity(chooserIntent)
            } else {
                Log.w(TAG, "No other handlers found for pkpass")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to forward pkpass intent: ", e)
        }
    }

    private fun isPassUriOrType(uriString: String, type: String?): Boolean {
        val lowerUri = uriString.lowercase(Locale.ROOT)
        val lowerType = (type ?: "").lowercase(Locale.ROOT)

        if (lowerUri.contains(".pkpass") || lowerUri.contains("pay.google.com") || lowerUri.contains("wallet.google.com")) {
            return true
        }

        if (lowerType.contains("pkpass") || lowerType.contains("vnd.apple.pkpass") || lowerType.contains("vnd-com.apple.pkpass")) {
            return true
        }

        return false
    }
}
