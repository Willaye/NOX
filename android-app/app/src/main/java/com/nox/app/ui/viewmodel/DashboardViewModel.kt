package com.nox.app.ui.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.nox.app.data.api.NoxApiService
import com.nox.app.data.model.*
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

data class DashboardUiState(
    val isLoading: Boolean = false,
    val devices: List<DeviceSummary> = emptyList(),
    val selectedDevice: DeviceDetail? = null,
    val activityLogs: List<ActivityLogItem> = emptyList(),
    val locationLogs: List<LocationLogItem> = emptyList(),
    val activityStats: ActivityStats? = null,
    val latestLocation: LocationLogItem? = null,
    val error: String? = null,
    val message: String? = null
)

@HiltViewModel
class DashboardViewModel @Inject constructor(
    private val api: NoxApiService
) : ViewModel() {

    private val _uiState = MutableStateFlow(DashboardUiState())
    val uiState: StateFlow<DashboardUiState> = _uiState

    fun loadDevices() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, error = null)
            try {
                val response = api.getDevices()
                if (response.isSuccessful) {
                    _uiState.value = _uiState.value.copy(
                        isLoading = false,
                        devices = response.body() ?: emptyList()
                    )
                } else {
                    _uiState.value = _uiState.value.copy(isLoading = false, error = "Failed to load devices")
                }
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(isLoading = false, error = "Connection error")
            }
        }
    }

    fun loadDeviceDetail(deviceId: String) {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, error = null)
            try {
                val response = api.getDevice(deviceId)
                if (response.isSuccessful) {
                    _uiState.value = _uiState.value.copy(
                        isLoading = false,
                        selectedDevice = response.body()
                    )
                }
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(isLoading = false, error = "Failed to load device")
            }
        }
    }

    fun loadActivityLogs(deviceId: String) {
        viewModelScope.launch {
            try {
                val response = api.getActivityLogs(deviceId)
                if (response.isSuccessful) {
                    _uiState.value = _uiState.value.copy(activityLogs = response.body() ?: emptyList())
                }
            } catch (_: Exception) {}
        }
    }

    fun loadActivityStats(deviceId: String) {
        viewModelScope.launch {
            try {
                val response = api.getActivityStats(deviceId)
                if (response.isSuccessful) {
                    _uiState.value = _uiState.value.copy(activityStats = response.body())
                }
            } catch (_: Exception) {}
        }
    }

    fun loadLocationLogs(deviceId: String) {
        viewModelScope.launch {
            try {
                val response = api.getLocationLogs(deviceId)
                if (response.isSuccessful) {
                    _uiState.value = _uiState.value.copy(locationLogs = response.body() ?: emptyList())
                }
            } catch (_: Exception) {}
        }
    }

    fun loadLatestLocation(deviceId: String) {
        viewModelScope.launch {
            try {
                val response = api.getLatestLocation(deviceId)
                if (response.isSuccessful) {
                    _uiState.value = _uiState.value.copy(latestLocation = response.body())
                }
            } catch (_: Exception) {}
        }
    }

    fun createDevice(name: String) {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true)
            try {
                val response = api.createDevice(CreateDeviceRequest(name))
                if (response.isSuccessful) {
                    _uiState.value = _uiState.value.copy(message = "Device created!")
                    loadDevices()
                } else {
                    _uiState.value = _uiState.value.copy(isLoading = false, error = "Failed to create device")
                }
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(isLoading = false, error = "Connection error")
            }
        }
    }

    fun pairDevice(pairingCode: String) {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true)
            try {
                val response = api.pairDevice(PairDeviceRequest(pairingCode))
                if (response.isSuccessful) {
                    _uiState.value = _uiState.value.copy(message = "Device paired!")
                    loadDevices()
                } else {
                    _uiState.value = _uiState.value.copy(isLoading = false, error = "Invalid pairing code")
                }
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(isLoading = false, error = "Connection error")
            }
        }
    }

    fun deleteDevice(deviceId: String) {
        viewModelScope.launch {
            try {
                val response = api.deleteDevice(deviceId)
                if (response.isSuccessful) {
                    _uiState.value = _uiState.value.copy(message = "Device removed")
                    loadDevices()
                }
            } catch (_: Exception) {}
        }
    }

    fun clearMessage() {
        _uiState.value = _uiState.value.copy(message = null, error = null)
    }
}
