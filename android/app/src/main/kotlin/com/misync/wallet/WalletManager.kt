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
import java.util.regex.Pattern
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

        // 3. IATA BCBP Boarding Pass Check
        if (rawBarcodeValue.startsWith("M1") && rawBarcodeValue.length > 20) {
            val iataPass = parseIataBoardingPass(rawBarcodeValue, barcodeFormat, backgroundColor, visionText, barcodeBoundingBox, imageWidth, imageHeight)
            if (iataPass != null) return iataPass
        }

        // 4. Spatial 2D Layout Extraction for Movie, Event, Transit, or Store Passes
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

    private fun parseIataBoardingPass(
        barcodeValue: String,
        barcodeFormat: String,
        bgColor: String,
        visionText: Text?,
        barcodeBox: Rect?,
        imageWidth: Int,
        imageHeight: Int
    ): Map<String, Any>? {
        try {
            val nameRaw = if (barcodeValue.length >= 22) barcodeValue.substring(2, 22).trim() else ""
            var passengerName = cleanPassengerName(nameRaw)

            var fromAirport = if (barcodeValue.length >= 33) barcodeValue.substring(30, 33).trim() else ""
            var toAirport = if (barcodeValue.length >= 36) barcodeValue.substring(33, 36).trim() else ""
            var airlineCode = if (barcodeValue.length >= 39) barcodeValue.substring(36, 39).trim() else ""
            var flightNum = if (barcodeValue.length >= 44) barcodeValue.substring(39, 44).trim().trimStart('0') else ""
            val rawSeatField = if (barcodeValue.length >= 52) barcodeValue.substring(48, 52).trim() else ""

            val isSouthwest = airlineCode == "WN" || barcodeValue.contains("BWN")

            var seat = ""
            var boardingPosition = ""

            if (isSouthwest && rawSeatField.isNotEmpty()) {
                if (rawSeatField.endsWith("A") || rawSeatField.endsWith("B") || rawSeatField.endsWith("C")) {
                    val groupLetter = rawSeatField.last()
                    val posNum = rawSeatField.dropLast(1).trimStart('0').padStart(2, '0')
                    boardingPosition = "$groupLetter / $posNum"
                }
            } else if (rawSeatField.isNotEmpty()) {
                seat = rawSeatField.trimStart('0')
            }

            var issuer = if (airlineCode.isNotEmpty()) getAirlineName(airlineCode) else "Airline"

            val allLines = if (visionText != null) getAllLines(visionText) else emptyList()
            val barcodeTopY = barcodeBox?.top ?: (imageHeight * 0.52).toInt()
            val cardLines = allLines.filter { line ->
                val box = line.boundingBox
                box != null && box.top < barcodeTopY && box.top > (imageHeight * 0.04)
            }

            val fieldsList = mutableListOf<Map<String, String>>()
            var gate = ""
            var boardingTime = ""
            var groupPos = boardingPosition

            if (cardLines.isNotEmpty()) {
                val rows = clusterIntoRows(cardLines)

                val firstRow = rows.firstOrNull()
                if (firstRow != null && firstRow.isNotEmpty()) {
                    val headerText = firstRow.first().text.trim()
                    if (headerText.contains("Southwest", true) || headerText.contains("Delta", true) ||
                        headerText.contains("United", true) || headerText.contains("American", true)) {
                        issuer = cleanIssuer(headerText)
                    }
                }

                var r = 1
                while (r < rows.size) {
                    val currentRow = rows[r]
                    val nextRow = if (r + 1 < rows.size) rows[r + 1] else null

                    val isLabelRow = currentRow.any { isLabelKeyword(it.text) }
                    if (isLabelRow && nextRow != null && nextRow.isNotEmpty()) {
                        val usedValueIndices = mutableSetOf<Int>()
                        for (labelLine in currentRow) {
                            val labelBox = labelLine.boundingBox ?: continue
                            val labelText = labelLine.text.trim()
                            val labelCenterX = labelBox.centerX()

                            var closestValIndex = -1
                            var minXDist = Int.MAX_VALUE
                            for (vIdx in nextRow.indices) {
                                if (usedValueIndices.contains(vIdx)) continue
                                val valBox = nextRow[vIdx].boundingBox ?: continue
                                val dist = abs(labelCenterX - valBox.centerX())
                                if (dist < minXDist) {
                                    minXDist = dist
                                    closestValIndex = vIdx
                                }
                            }

                            if (closestValIndex != -1 && minXDist < imageWidth * 0.45) {
                                usedValueIndices.add(closestValIndex)
                                val valText = nextRow[closestValIndex].text.trim()
                                val cleanLbl = cleanLabel(labelText)

                                if (cleanLbl.contains("Gate", true)) gate = valText
                                else if (cleanLbl.contains("Boarding", true)) boardingTime = valText
                                else if (cleanLbl.contains("Group", true) || cleanLbl.contains("Position", true)) groupPos = valText
                                else if (cleanLbl.contains("Seat", true) && !isSouthwest) seat = valText
                                else if (cleanLbl.contains("Passenger", true)) passengerName = cleanPassengerName(valText)
                                else if (!isGenericWord(valText) && valText != cleanLbl) {
                                    fieldsList.add(mapOf("label" to cleanLbl, "value" to valText))
                                }
                            }
                        }
                        r += 2
                        continue
                    }
                    r++
                }
            }

            val orderedFields = mutableListOf<Map<String, String>>()
            if (flightNum.isNotEmpty()) {
                val flightLabel = if (airlineCode.isNotEmpty()) "$airlineCode $flightNum" else "Flight $flightNum"
                orderedFields.add(mapOf("label" to "Flight", "value" to flightLabel))
            }
            if (fromAirport.isNotEmpty() && toAirport.isNotEmpty()) {
                orderedFields.add(mapOf("label" to "Route", "value" to "$fromAirport → $toAirport"))
            }
            if (passengerName.isNotEmpty()) {
                orderedFields.add(mapOf("label" to "Passenger", "value" to passengerName))
            }
            if (seat.isNotEmpty()) {
                orderedFields.add(mapOf("label" to "Seat", "value" to seat))
            }
            if (groupPos.isNotEmpty()) {
                orderedFields.add(mapOf("label" to "Group / Pos", "value" to groupPos))
            }
            if (gate.isNotEmpty()) {
                orderedFields.add(mapOf("label" to "Gate", "value" to gate))
            }
            if (boardingTime.isNotEmpty()) {
                orderedFields.add(mapOf("label" to "Boarding", "value" to boardingTime))
            }

            orderedFields.addAll(fieldsList)

            val title = if (fromAirport.isNotEmpty() && toAirport.isNotEmpty()) "$fromAirport → $toAirport" else if (flightNum.isNotEmpty()) "Flight $flightNum" else issuer
            val id = "${issuer.lowercase(Locale.ROOT).replace("[^a-z0-9]".toRegex(), "_")}_${fromAirport}_${toAirport}_${flightNum}".ifBlank { "pass_${System.currentTimeMillis()}" }

            return buildPassMap(
                id = id,
                issuer = issuer,
                title = title,
                type = "boardingPass",
                backgroundColor = if (bgColor != "#111827") bgColor else "#0D1B3E",
                barcodeValue = barcodeValue,
                barcodeFormat = barcodeFormat,
                fields = orderedFields
            )
        } catch (e: Exception) {
            Log.e(TAG, "Error in parseIataBoardingPass: ", e)
            return null
        }
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

        val barcodeTopY = barcodeBox?.top ?: (imageHeight * 0.52).toInt()

        // 1. Identify Issuer from the top-most header text (Y < 0.16H)
        var issuer = "Pass"
        val topLines = if (visionText != null) {
            getAllLines(visionText).filter {
                val box = it.boundingBox
                box != null && box.top < imageHeight * 0.16 && box.top > (imageHeight * 0.04)
            }.sortedBy { it.boundingBox?.top ?: 0 }
        } else emptyList()

        if (topLines.isNotEmpty()) {
            issuer = cleanIssuer(topLines.first().text)
        }

        // 2. Identify Hero Title (supports multi-line titles like "The Matrix in Shared Reality")
        var title = ""
        val titleLineTexts = mutableSetOf<String>()

        if (visionText != null) {
            // Find text blocks in the upper region (0.08H to 0.48H)
            val candidateBlocks = visionText.textBlocks.filter { block ->
                val box = block.boundingBox
                box != null && box.top < (imageHeight * 0.48) && box.top > (imageHeight * 0.08) &&
                        !isGenericWord(block.text) && !isLabelKeyword(block.text)
            }

            // Pick the block with the largest average line height (font size)
            val heroBlock = candidateBlocks.maxByOrNull { block ->
                val lineCount = block.lines.size.coerceAtLeast(1)
                (block.boundingBox?.height() ?: 0) / lineCount
            }

            if (heroBlock != null && heroBlock.text.isNotBlank()) {
                val blockText = heroBlock.text.replace("\n", " ").trim()
                if (blockText.length in 3..60 && !isGenericWord(blockText)) {
                    title = cleanTitle(blockText)
                    for (line in heroBlock.lines) {
                        titleLineTexts.add(line.text.trim())
                    }
                }
            }
        }

        // 3. Extract remaining card lines for structured fields
        val allLines = if (visionText != null) getAllLines(visionText) else emptyList()
        val cardLines = allLines.filter { line ->
            val box = line.boundingBox
            val text = line.text.trim()
            box != null && box.top < barcodeTopY && box.top > (imageHeight * 0.05) &&
                    text != issuer && !titleLineTexts.contains(text) && text != title
        }

        val fieldsList = mutableListOf<Map<String, String>>()

        if (cardLines.isNotEmpty()) {
            val rows = clusterIntoRows(cardLines)
            var r = 0

            while (r < rows.size) {
                val currentRow = rows[r]
                val nextRow = if (r + 1 < rows.size) rows[r + 1] else null

                // Case A: Label Row followed by Value Row (e.g. Section, Level, Sub-Sec -> Dome, 2, Right)
                val isLabelRow = currentRow.any { isLabelKeyword(it.text) }

                if (isLabelRow && nextRow != null && nextRow.isNotEmpty()) {
                    val usedValueIndices = mutableSetOf<Int>()
                    for (labelLine in currentRow) {
                        val labelBox = labelLine.boundingBox ?: continue
                        val labelText = labelLine.text.trim()
                        val labelCenterX = labelBox.centerX()

                        var closestValIndex = -1
                        var minXDist = Int.MAX_VALUE

                        for (vIdx in nextRow.indices) {
                            if (usedValueIndices.contains(vIdx)) continue
                            val valBox = nextRow[vIdx].boundingBox ?: continue
                            val dist = abs(labelCenterX - valBox.centerX())
                            if (dist < minXDist) {
                                minXDist = dist
                                closestValIndex = vIdx
                            }
                        }

                        if (closestValIndex != -1 && minXDist < imageWidth * 0.40) {
                            usedValueIndices.add(closestValIndex)
                            val valText = nextRow[closestValIndex].text.trim()
                            fieldsList.add(mapOf("label" to cleanLabel(labelText), "value" to valText))
                        } else {
                            // Smart detection for standalone label
                            addFieldSmart(labelText, fieldsList)
                        }
                    }

                    for (vIdx in nextRow.indices) {
                        if (!usedValueIndices.contains(vIdx)) {
                            val leftoverText = nextRow[vIdx].text.trim()
                            addFieldSmart(leftoverText, fieldsList)
                        }
                    }

                    r += 2
                    continue
                }

                // Case B: Process single row
                for (line in currentRow) {
                    val text = line.text.trim()
                    if (text == title || isGenericWord(text) || titleLineTexts.contains(text)) continue

                    if (isInlineKeyValue(text)) {
                        val parts = text.split(":", limit = 2)
                        fieldsList.add(mapOf("label" to cleanLabel(parts[0]), "value" to parts[1].trim()))
                    } else {
                        addFieldSmart(text, fieldsList)
                    }
                }

                r++
            }
        }

        if (title.isBlank()) {
            title = if (issuer != "Pass") issuer else "Event Pass"
        }

        val id = "${issuer.lowercase(Locale.ROOT).replace("[^a-z0-9]".toRegex(), "_")}_${rawBarcodeValue.takeLast(12)}".ifBlank { "pass_${System.currentTimeMillis()}" }

        return buildPassMap(
            id = id,
            issuer = issuer,
            title = title,
            type = if (title.contains("Flight", true) || title.contains("→")) "boardingPass" else "eventTicket",
            backgroundColor = backgroundColor,
            barcodeValue = rawBarcodeValue,
            barcodeFormat = barcodeFormat,
            fields = fieldsList
        )
    }

    private fun addFieldSmart(text: String, fieldsList: MutableList<Map<String, String>>) {
        val trimmed = text.trim()
        if (trimmed.isBlank() || isGenericWord(trimmed) || trimmed.length > 50) return

        // 1. Time Match: "09:00 PM", "4:20pm", "19:30"
        if (trimmed.matches("^(?:\\d{1,2}:\\d{2}(?:\\s*(?:AM|PM|am|pm))?)$".toRegex())) {
            fieldsList.add(mapOf("label" to "Time", "value" to trimmed))
            return
        }

        // 2. Date Match: "Aug 17, 2026", "May 9, 2026", "11/24/2024"
        if (trimmed.matches("^(?:(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\\s+\\d{1,2}(?:,\\s*\\d{4})?|\\d{1,2}/\\d{1,2}/\\d{2,4})$".toRegex(RegexOption.IGNORE_CASE))) {
            fieldsList.add(mapOf("label" to "Date", "value" to trimmed))
            return
        }

        // 3. Venue / Location Match: e.g. "Cosm Atlanta", "Midtown Art Cinema", "Walter Kerr Theatre"
        if (trimmed.contains("Atlanta", true) || trimmed.contains("Cinema", true) ||
            trimmed.contains("Theatre", true) || trimmed.contains("Center", true) ||
            trimmed.contains("Hall", true) || trimmed.contains("Arena", true) ||
            trimmed.contains("Stadium", true)) {
            fieldsList.add(mapOf("label" to "Venue", "value" to trimmed))
            return
        }

        // 4. Admission / General Info
        if (trimmed.contains("Admission", true) || trimmed.contains("Pass", true)) {
            fieldsList.add(mapOf("label" to "Type", "value" to trimmed))
            return
        }

        fieldsList.add(mapOf("label" to "Info", "value" to trimmed))
    }

    private fun clusterIntoRows(lines: List<Text.Line>): List<List<Text.Line>> {
        val sortedLines = lines.sortedBy { it.boundingBox?.top ?: 0 }
        val rows = mutableListOf<MutableList<Text.Line>>()

        for (line in sortedLines) {
            val box = line.boundingBox ?: continue
            val centerY = box.centerY()

            val matchingRow = rows.find { row ->
                val rowCenterY = row.firstOrNull()?.boundingBox?.centerY() ?: 0
                abs(centerY - rowCenterY) <= 18
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

    private fun isGenericWord(text: String): Boolean {
        val lower = text.lowercase(Locale.ROOT).trim()
        return lower == "tickets" || lower == "ticket" || lower == "pass" || lower == "passes" ||
                lower == "boarding pass" || lower == "details" || lower == "show details" ||
                lower == "admission"
    }

    private fun isLabelKeyword(text: String): Boolean {
        val lower = text.lowercase(Locale.ROOT).trim()
        return lower == "date" || lower == "time" || lower == "screen" || lower == "seat" ||
                lower == "row" || lower == "section" || lower == "row / seat" || lower == "row/seat" ||
                lower == "gate" || lower == "terminal" || lower == "boarding" || lower == "cabin" ||
                lower == "passenger" || lower == "valid until" || lower == "rides used" ||
                lower == "group / position" || lower == "group/position" || lower == "member" ||
                lower == "account" || lower == "venue" || lower == "visit date" || lower == "start time" ||
                lower == "admission tickets" || lower == "extras" || lower == "level" ||
                lower == "sub-sec" || lower == "sub-section" || lower == "subsec" ||
                lower == "tier" || lower == "box"
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

    private fun cleanIssuer(text: String): String {
        return text.replace("Landmark Theatres", "Landmark Theatres", ignoreCase = true)
            .replace("SeatGeek", "SeatGeek", ignoreCase = true)
            .replace("Southwest Airlines", "Southwest", ignoreCase = true)
            .replace("Delta Air Lines", "Delta", ignoreCase = true)
            .replace("Las Vegas Monorail", "Las Vegas Monorail", ignoreCase = true)
            .trim()
    }

    private fun cleanTitle(text: String): String {
        return text.replace("\n", " ").trim()
    }

    private fun cleanLabel(text: String): String {
        val clean = text.replace(":", "").trim()
        return clean.split(" ").joinToString(" ") { w ->
            if (w.isEmpty()) "" else w.substring(0, 1).uppercase(Locale.ROOT) + w.substring(1).lowercase(Locale.ROOT)
        }
    }

    private fun cleanPassengerName(raw: String): String {
        val cleaned = raw.replace("\n", " ").trim()
        if (cleaned.contains("/")) {
            val parts = cleaned.split("/")
            val last = parts[0].trim()
            val first = parts[1].replace("MR", "").replace("MS", "").replace("MRS", "").trim()
            return "$first $last".trim()
        }
        return cleaned
    }

    private fun getAirlineName(code: String): String {
        return when (code.uppercase(Locale.ROOT)) {
            "DL", "DAL" -> "Delta"
            "WN", "SWA" -> "Southwest"
            "AA", "AAL" -> "American Airlines"
            "UA", "UAL" -> "United Airlines"
            "B6", "JBU" -> "JetBlue"
            "AS", "ASA" -> "Alaska Airlines"
            else -> code
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
