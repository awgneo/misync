package com.misync.misync.device

import android.content.Context
import android.location.Geocoder
import android.location.Location
import android.util.Log
import java.util.Locale

class LocationManager(private val context: Context) {
    private val TAG = "LocationManager"

    fun getLocation(): Map<String, Any>? {
        Log.d(TAG, "getLocation: querying LocationManager")
        val locationManager = context.getSystemService(Context.LOCATION_SERVICE) as android.location.LocationManager
        val providers = locationManager.getProviders(true)
        var bestLocation: Location? = null
        for (provider in providers) {
            try {
                val loc = locationManager.getLastKnownLocation(provider) ?: continue
                if (bestLocation == null || loc.accuracy < bestLocation.accuracy) {
                    bestLocation = loc
                }
            } catch (e: SecurityException) {
                Log.e(TAG, "Location permission not granted for provider $provider", e)
            }
        }
        if (bestLocation != null) {
            var cityName = "Current Location"
            try {
                val geocoder = Geocoder(context, Locale.getDefault())
                @Suppress("DEPRECATION")
                val addresses = geocoder.getFromLocation(bestLocation.latitude, bestLocation.longitude, 1)
                if (!addresses.isNullOrEmpty()) {
                    val address = addresses[0]
                    cityName = address.locality ?: address.subAdminArea ?: address.adminArea ?: "Current Location"
                }
            } catch (e: Exception) {
                Log.e(TAG, "Geocoder failed to get city name", e)
            }
            Log.d(TAG, "getLocation: found lat=${bestLocation.latitude}, lon=${bestLocation.longitude}, city=$cityName")
            return mapOf(
                "latitude" to bestLocation.latitude,
                "longitude" to bestLocation.longitude,
                "cityName" to cityName
            )
        }
        Log.w(TAG, "getLocation: no last known location found")
        return null
    }
}
