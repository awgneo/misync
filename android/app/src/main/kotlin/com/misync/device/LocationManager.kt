package com.misync.device

import android.content.Context
import android.location.Geocoder
import android.location.Location
import android.location.LocationListener
import android.os.Build
import android.os.Bundle
import android.util.Log
import java.util.Locale

class LocationManager(private val context: Context) {
    private val TAG = "LocationManager"
    private var locationListener: LocationListener? = null

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

    fun startLocationUpdates(onLocationChanged: (Map<String, Any>) -> Unit): Boolean {
        Log.d(TAG, "startLocationUpdates: starting updates")
        val locationManager = context.getSystemService(Context.LOCATION_SERVICE) as android.location.LocationManager
        
        if (locationListener != null) {
            stopLocationUpdates()
        }

        locationListener = object : LocationListener {
            override fun onLocationChanged(location: Location) {
                Log.d(TAG, "locationUpdate: lat=${location.latitude}, lon=${location.longitude}")
                val verticalAccuracy = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    location.verticalAccuracyMeters
                } else {
                    0.0f
                }
                val map = mapOf(
                    "latitude" to location.latitude,
                    "longitude" to location.longitude,
                    "altitude" to location.altitude,
                    "speed" to location.speed,
                    "bearing" to location.bearing,
                    "horizontalAccuracy" to location.accuracy,
                    "verticalAccuracy" to verticalAccuracy
                )
                onLocationChanged(map)
            }
            override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}
            override fun onProviderEnabled(provider: String) {}
            override fun onProviderDisabled(provider: String) {}
        }

        var started = false
        try {
            if (locationManager.isProviderEnabled(android.location.LocationManager.GPS_PROVIDER)) {
                locationManager.requestLocationUpdates(
                    android.location.LocationManager.GPS_PROVIDER,
                    2000L,
                    1.0f,
                    locationListener!!
                )
                started = true
            }
            if (locationManager.isProviderEnabled(android.location.LocationManager.NETWORK_PROVIDER)) {
                locationManager.requestLocationUpdates(
                    android.location.LocationManager.NETWORK_PROVIDER,
                    2000L,
                    1.0f,
                    locationListener!!
                )
                started = true
            }
        } catch (e: SecurityException) {
            Log.e(TAG, "startLocationUpdates: permission not granted", e)
        } catch (e: Exception) {
            Log.e(TAG, "startLocationUpdates: error requesting updates", e)
        }

        return started
    }

    fun stopLocationUpdates() {
        Log.d(TAG, "stopLocationUpdates: stopping updates")
        val listener = locationListener ?: return
        val locationManager = context.getSystemService(Context.LOCATION_SERVICE) as android.location.LocationManager
        try {
            locationManager.removeUpdates(listener)
        } catch (e: Exception) {
            Log.e(TAG, "stopLocationUpdates: error removing updates", e)
        }
        locationListener = null
    }
}

