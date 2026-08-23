package com.misync.wallet

import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.Rect
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.google.android.gms.tasks.Tasks
import com.google.mlkit.vision.barcode.BarcodeScannerOptions
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.Text
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import io.flutter.plugin.common.MethodChannel
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import kotlin.math.abs

class WalletManager(private val context: Context) {
    private val TAG = "WalletManager"
    private var pendingPassMap: Map<String, Any>? = null

    private val barcodeScanner = BarcodeScanning.getClient(
        BarcodeScannerOptions.Builder()
            .setBarcodeFormats(Barcode.FORMAT_ALL_FORMATS)
            .build()
    )

    private val textRecognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)

    fun handleIntent(intent: Intent, methodChannel: MethodChannel?): Boolean {
        val action = intent.action
        Log.d(TAG, "handleIntent called: action=$action, type=${intent.type}")

        if (Intent.ACTION_SEND != action && Intent.ACTION_SEND_MULTIPLE != action) {
            return false
        }

        val uri: Uri? = if (Intent.ACTION_SEND == action) {
            intent.getParcelableExtra(Intent.EXTRA_STREAM) ?: intent.data
        } else {
            val list = intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)
            list?.firstOrNull()
        }

        if (uri == null) {
            Log.e(TAG, "No image URI found in screenshot share intent")
            return false
        }

        Log.d(TAG, "Captured screenshot URI for pass ingestion: $uri")

        Thread {
            try {
                val passMap = processScreenshotUri(uri)
                if (passMap != null) {
                    Log.d(TAG, "Successfully extracted pass from screenshot: $passMap")
                    pendingPassMap = passMap
                    Handler(Looper.getMainLooper()).post {
                        methodChannel?.invokeMethod("passIntercepted", passMap)
                    }

                    // Auto-delete the screenshot after capturing the pass
                    tryDeleteScreenshot(uri)
                } else {
                    Log.e(TAG, "Failed to extract barcode or pass data from screenshot: $uri")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error processing screenshot URI: ", e)
            }
        }.start()

        return true
    }

    fun consumePendingPass(result: MethodChannel.Result) {
        val pass = pendingPassMap
        pendingPassMap = null
        result.success(pass)
    }

    private fun processScreenshotUri(uri: Uri): Map<String, Any>? {
        val inputImage = try {
            InputImage.fromFilePath(context, uri)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to create InputImage from URI: $uri", e)
            return null
        }

        val bitmap = loadSampledBitmap(uri)
        val backgroundColor = sampleDominantCardColor(bitmap)

        // 1. Run Barcode Scanning
        val barcodeTask = barcodeScanner.process(inputImage)
        val barcodes = try {
            Tasks.await(barcodeTask)
        } catch (e: Exception) {
            Log.e(TAG, "Barcode scanner task failed: ", e)
            emptyList<Barcode>()
        }

        val primaryBarcode = barcodes.firstOrNull()
        val rawBarcodeValue = primaryBarcode?.rawValue ?: primaryBarcode?.displayValue ?: ""
        val barcodeFormat = mapBarcodeFormat(primaryBarcode?.format ?: Barcode.FORMAT_QR_CODE)
        val barcodeBoundingBox = primaryBarcode?.boundingBox

        Log.d(TAG, "Detected barcode: value='$rawBarcodeValue', format=$barcodeFormat")

        // 2. Run Text Recognition (OCR)
        val textTask = textRecognizer.process(inputImage)
        val visionText = try {
            Tasks.await(textTask)
        } catch (e: Exception) {
            Log.e(TAG, "Text recognizer task failed: ", e)
            null
        }

        val imageWidth = inputImage.width.coerceAtLeast(1)
        val imageHeight = inputImage.height.coerceAtLeast(1)

        // 3. Pure 2D OCR Layout Extraction
        return parseSpatialPass(
            rawBarcodeValue = rawBarcodeValue,
            barcodeFormat = barcodeFormat,
            backgroundColor = backgroundColor,
            visionText = visionText,
            barcodeBox = barcodeBoundingBox,
            imageWidth = imageWidth,
            imageHeight = imageHeight
        )
    }

    private fun parseSpatialPass(
        rawBarcodeValue: String,
        barcodeFormat: String,
        backgroundColor: String,
        visionText: Text?,
        barcodeBox: Rect?,
        imageWidth: Int,
        imageHeight: Int
    ): Map<String, Any>? {
        if (rawBarcodeValue.isEmpty() && visionText == null) return null

        val allLines = if (visionText != null) getAllLines(visionText) else emptyList()
        if (allLines.isEmpty() && rawBarcodeValue.isEmpty()) return null

        // 1. Barcode Cutoff: Ignore any OCR text whose vertical center is inside or below the barcode
        val barcodeTopY = barcodeBox?.top ?: (imageHeight * 0.55).toInt()
        val cardLines = allLines.filter { line ->
            val box = line.boundingBox
            box != null && box.top > (imageHeight * 0.03) && box.top < barcodeTopY && box.centerY() < barcodeTopY
        }

        // 2. Issuer Identification: Top-most header line(s) (Y < 0.18H)
        var issuer = "Pass"
        val topHeaderLines = cardLines.filter { line ->
            val box = line.boundingBox
            box != null && box.top < (imageHeight * 0.18)
        }.sortedBy { it.boundingBox?.top ?: 0 }

        val usedLineTexts = mutableSetOf<String>()
        val fieldsList = mutableListOf<Map<String, String>>()

        if (topHeaderLines.isNotEmpty()) {
            val headerRows = clusterIntoRows(topHeaderLines)
            val firstHeaderRow = headerRows.firstOrNull() ?: emptyList()

            if (firstHeaderRow.isNotEmpty()) {
                val headerItems = firstHeaderRow.map { it.text.trim() }
                for (item in headerItems) {
                    usedLineTexts.add(item)
                }

                val lastItem = headerItems.last()
                if (headerItems.size > 1 && lastItem.matches("^[A-Z0-9]{2,3}\\s*\\d{1,4}$".toRegex())) {
                    issuer = headerItems.dropLast(1).joinToString(" ").ifBlank { "Pass" }
                    fieldsList.add(mapOf("label" to "Flight", "value" to lastItem))
                } else {
                    issuer = headerItems.joinToString(" ").ifBlank { "Pass" }
                }
            }
        }

        // 3. Hero Title Identification: Prominent lines with largest font height in upper card region (0.06H to 0.48H)
        var title = ""
        var titleTopY = 0
        var titleBottomY = 0

        val candidateTitleLines = cardLines.filter { line ->
            val box = line.boundingBox
            box != null && box.top < (imageHeight * 0.48) && box.top > (imageHeight * 0.06) && !usedLineTexts.contains(line.text.trim())
        }.sortedBy { it.boundingBox?.top ?: 0 }

        if (candidateTitleLines.isNotEmpty()) {
            val maxLineHeight = candidateTitleLines.maxOf { it.boundingBox?.height() ?: 0 }
            val titleLines = candidateTitleLines.filter { line ->
                val h = line.boundingBox?.height() ?: 0
                h >= maxLineHeight * 0.68
            }

            if (titleLines.isNotEmpty()) {
                title = titleLines.joinToString(" ") { it.text.trim() }
                titleTopY = titleLines.first().boundingBox?.top ?: 0
                titleBottomY = titleLines.last().boundingBox?.bottom ?: 0
                for (l in titleLines) {
                    usedLineTexts.add(l.text.trim())
                }
            }
        }

        // 4. Subtitle / Venue Line: Text directly above the Hero Title
        if (titleTopY > 0) {
            val subheaderLines = cardLines.filter { line ->
                val box = line.boundingBox
                val text = line.text.trim()
                box != null && box.bottom <= (titleTopY + 5) && !usedLineTexts.contains(text) && text != issuer
            }.sortedBy { it.boundingBox?.top ?: 0 }

            if (subheaderLines.isNotEmpty()) {
                val subheaderText = subheaderLines.joinToString(" ") { it.text.trim() }
                val label = when {
                    subheaderText.contains(" to ", true) || subheaderText.contains("→") || subheaderText.contains("✈") -> "Route"
                    else -> "Venue"
                }
                fieldsList.add(mapOf("label" to label, "value" to subheaderText))
                for (l in subheaderLines) {
                    usedLineTexts.add(l.text.trim())
                }
            }
        }

        // 5. Structured Field Extraction: Stacked Label-Value Rows, Inline Key-Values, and Date/Time
        val contentLines = cardLines.filter { line ->
            val box = line.boundingBox
            val text = line.text.trim()
            box != null && box.top >= (titleBottomY - 10) && !usedLineTexts.contains(text) && text != title && text != issuer
        }

        if (contentLines.isNotEmpty()) {
            val rows = clusterIntoRows(contentLines)
            var r = 0

            while (r < rows.size) {
                val currentRow = rows[r]
                val nextRow = if (r + 1 < rows.size) rows[r + 1] else null

                // Check if currentRow is a row of labels for nextRow
                val isStackedGrid = nextRow != null && nextRow.isNotEmpty() && isLikelyLabelRow(currentRow, nextRow)

                if (isStackedGrid && nextRow != null) {
                    val usedValueIndices = mutableSetOf<Int>()

                    for (labelLine in currentRow) {
                        val labelBox = labelLine.boundingBox ?: continue
                        val labelText = labelLine.text.trim()

                        var closestValIndex = -1
                        var minXDist = Int.MAX_VALUE

                        for (vIdx in nextRow.indices) {
                            if (usedValueIndices.contains(vIdx)) continue
                            val valBox = nextRow[vIdx].boundingBox ?: continue
                            val dist = calculateColumnDistance(labelBox, valBox)
                            if (dist < minXDist) {
                                minXDist = dist
                                closestValIndex = vIdx
                            }
                        }

                        if (closestValIndex != -1 && minXDist < imageWidth * 0.45) {
                            usedValueIndices.add(closestValIndex)
                            val valText = nextRow[closestValIndex].text.trim()
                            fieldsList.add(mapOf("label" to cleanLabel(labelText), "value" to valText))
                        }
                    }

                    r += 2
                    continue
                }

                // Inline Key:Value rows or standalone Time/Date values
                for (line in currentRow) {
                    val text = line.text.trim()
                    if (isInlineKeyValue(text)) {
                        val parts = text.split(":", limit = 2)
                        fieldsList.add(mapOf("label" to cleanLabel(parts[0]), "value" to parts[1].trim()))
                    } else if (isTimeValue(text)) {
                        fieldsList.add(mapOf("label" to "Time", "value" to text))
                    } else if (isDateValue(text)) {
                        fieldsList.add(mapOf("label" to "Date", "value" to text))
                    }
                }

                r++
            }
        }

        if (title.isBlank()) {
            title = if (issuer != "Pass") issuer else "Pass"
        }

        val id = "${issuer.lowercase(Locale.ROOT).replace("[^a-z0-9]".toRegex(), "_")}_${rawBarcodeValue.takeLast(12)}".ifBlank { "pass_${System.currentTimeMillis()}" }
        val passType = if (title.contains("Flight", true) || title.contains("→") || title.contains("✈") || barcodeFormat == "PKBarcodeFormatAztec" || barcodeFormat == "PKBarcodeFormatPDF417") {
            "boardingPass"
        } else {
            "eventTicket"
        }

        return buildPassMap(
            id = id,
            issuer = issuer,
            title = title,
            type = passType,
            backgroundColor = backgroundColor,
            barcodeValue = rawBarcodeValue,
            barcodeFormat = barcodeFormat,
            fields = fieldsList
        )
    }

    private fun isTimeValue(text: String): Boolean {
        return text.matches("^(?:\\d{1,2}:\\d{2}(?:\\s*(?:AM|PM|am|pm))?)$".toRegex())
    }

    private fun isDateValue(text: String): Boolean {
        return text.matches("^(?:(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\\s+\\d{1,2}(?:,\\s*\\d{4})?|\\d{1,2}/\\d{1,2}/\\d{2,4})$".toRegex(RegexOption.IGNORE_CASE))
    }

    private fun calculateColumnDistance(labelBox: Rect, valBox: Rect): Int {
        val centerDist = abs(labelBox.centerX() - valBox.centerX())
        val leftDist = abs(labelBox.left - valBox.left)
        val rightDist = abs(labelBox.right - valBox.right)
        return minOf(centerDist, leftDist, rightDist)
    }

    private fun isLikelyLabelRow(currentRow: List<Text.Line>, nextRow: List<Text.Line>): Boolean {
        // Time and Date strings are values, never labels for other rows
        if (currentRow.any { isTimeValue(it.text.trim()) || isDateValue(it.text.trim()) }) return false

        var pairedCount = 0
        for (cLine in currentRow) {
            val cBox = cLine.boundingBox ?: continue
            if (nextRow.any { nLine ->
                val nBox = nLine.boundingBox ?: return@any false
                val dist = calculateColumnDistance(cBox, nBox)
                dist < (cBox.width().coerceAtLeast(nBox.width()) * 1.5).coerceAtLeast(80.0)
            }) {
                pairedCount++
            }
        }

        return pairedCount >= (currentRow.size / 2.0).coerceAtLeast(1.0)
    }

    private fun clusterIntoRows(lines: List<Text.Line>): List<List<Text.Line>> {
        val sortedLines = lines.sortedBy { it.boundingBox?.top ?: 0 }
        val rows = mutableListOf<MutableList<Text.Line>>()

        for (line in sortedLines) {
            val box = line.boundingBox ?: continue
            val centerY = box.centerY()
            val lineHeight = box.height().coerceAtLeast(20)
            val tolerance = (lineHeight * 0.85).toInt().coerceIn(20, 45)

            val matchingRow = rows.find { row ->
                val rowCenterY = row.firstOrNull()?.boundingBox?.centerY() ?: 0
                abs(centerY - rowCenterY) <= tolerance
            }

            if (matchingRow != null) {
                matchingRow.add(line)
            } else {
                rows.add(mutableListOf(line))
            }
        }

        for (row in rows) {
            row.sortBy { it.boundingBox?.left ?: 0 }
        }

        return rows
    }

    private fun isInlineKeyValue(text: String): Boolean {
        if (!text.contains(":")) return false
        if (text.matches(".*\\d{1,2}:\\d{2}.*".toRegex())) return false
        val parts = text.split(":", limit = 2)
        return parts.size == 2 && parts[0].trim().length in 2..20 && parts[1].trim().isNotBlank()
    }

    private fun getAllLines(visionText: Text): List<Text.Line> {
        val list = mutableListOf<Text.Line>()
        for (block in visionText.textBlocks) {
            for (line in block.lines) {
                list.add(line)
            }
        }
        return list
    }

    private fun cleanLabel(text: String): String {
        val clean = text.replace(":", "").trim()
        return clean.split(" ").joinToString(" ") { w ->
            if (w.isEmpty()) ""
            else if (w == "/" || w == "&" || w == "-") w
            else w.substring(0, 1).uppercase(Locale.ROOT) + w.substring(1).lowercase(Locale.ROOT)
        }
    }

    private fun mapBarcodeFormat(format: Int): String {
        return when (format) {
            Barcode.FORMAT_AZTEC -> "PKBarcodeFormatAztec"
            Barcode.FORMAT_PDF417 -> "PKBarcodeFormatPDF417"
            Barcode.FORMAT_CODE_128 -> "PKBarcodeFormatCode128"
            Barcode.FORMAT_DATA_MATRIX -> "PKBarcodeFormatDataMatrix"
            else -> "PKBarcodeFormatQR"
        }
    }

    private fun sampleDominantCardColor(bitmap: Bitmap?): String {
        if (bitmap == null) return "#111827"
        try {
            val width = bitmap.width
            val height = bitmap.height

            val sampleYStart = (height * 0.15).toInt()
            val sampleYEnd = (height * 0.38).toInt()
            val sampleXStart = (width * 0.20).toInt()
            val sampleXEnd = (width * 0.80).toInt()

            var rSum = 0L
            var gSum = 0L
            var bSum = 0L
            var count = 0

            val step = 10
            for (y in sampleYStart until sampleYEnd step step) {
                for (x in sampleXStart until sampleXEnd step step) {
                    val pixel = bitmap.getPixel(x, y)
                    val r = Color.red(pixel)
                    val g = Color.green(pixel)
                    val b = Color.blue(pixel)

                    if (r > 240 && g > 240 && b > 240) continue

                    rSum += r
                    gSum += g
                    bSum += b
                    count++
                }
            }

            if (count > 0) {
                val avgR = (rSum / count).toInt().coerceIn(0, 255)
                val avgG = (gSum / count).toInt().coerceIn(0, 255)
                val avgB = (bSum / count).toInt().coerceIn(0, 255)
                return String.format("#%02x%02x%02x", avgR, avgG, avgB)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to sample color: ", e)
        }
        return "#111827"
    }

    private fun loadSampledBitmap(uri: Uri): Bitmap? {
        return try {
            val options = BitmapFactory.Options().apply {
                inSampleSize = 4
            }
            context.contentResolver.openInputStream(uri)?.use { stream ->
                BitmapFactory.decodeStream(stream, null, options)
            }
        } catch (e: Exception) {
            null
        }
    }

    private fun tryDeleteScreenshot(uri: Uri) {
        try {
            val deleted = context.contentResolver.delete(uri, null, null)
            Log.d(TAG, "Screenshot deletion result for $uri: deleted=$deleted")
        } catch (e: Exception) {
            Log.d(TAG, "Screenshot auto-deletion skipped (scoped storage permissions): ${e.message}")
        }
    }

    private fun buildPassMap(
        id: String,
        issuer: String,
        title: String,
        type: String,
        backgroundColor: String,
        barcodeValue: String,
        barcodeFormat: String,
        fields: List<Map<String, String>>
    ): Map<String, Any> {
        val isoFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US).apply {
            timeZone = TimeZone.getTimeZone("UTC")
        }
        val createdAt = isoFormat.format(Date())

        val fgColor = if (isLightColor(backgroundColor)) "#111827" else "#ffffff"

        return mapOf(
            "id" to id,
            "issuer" to issuer,
            "title" to title,
            "type" to type,
            "backgroundColor" to backgroundColor,
            "foregroundColor" to fgColor,
            "barcodeValue" to barcodeValue,
            "barcodeFormat" to barcodeFormat,
            "fields" to fields,
            "createdAt" to createdAt
        )
    }

    private fun isLightColor(hex: String): Boolean {
        return try {
            val color = Color.parseColor(hex)
            val r = Color.red(color)
            val g = Color.green(color)
            val b = Color.blue(color)
            val luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0
            luminance > 0.70
        } catch (e: Exception) {
            false
        }
    }
}
