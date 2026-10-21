package com.nox.app.ui.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.nox.app.data.api.NoxApiService
import com.nox.app.data.auth.TokenManager
import com.nox.app.data.model.LoginRequest
import com.nox.app.data.model.SignupRequest
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

data class AuthUiState(
    val isLoading: Boolean = false,
    val isLoggedIn: Boolean = false,
    val error: String? = null,
    val userName: String? = null
)

@HiltViewModel
class AuthViewModel @Inject constructor(
    private val api: NoxApiService,
    private val tokenManager: TokenManager
) : ViewModel() {

    private val _uiState = MutableStateFlow(AuthUiState())
    val uiState: StateFlow<AuthUiState> = _uiState

    init {
        viewModelScope.launch {
            val loggedIn = tokenManager.isLoggedIn()
            _uiState.value = _uiState.value.copy(
                isLoggedIn = loggedIn,
                userName = tokenManager.getUserEmail()
            )
        }
    }

    fun login(email: String, password: String) {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, error = null)
            try {
                val response = api.login(LoginRequest(email, password))
                if (response.isSuccessful && response.body() != null) {
                    val body = response.body()!!
                    tokenManager.saveAuth(body.accessToken, body.user.id, body.user.email)
                    _uiState.value = _uiState.value.copy(
                        isLoading = false,
                        isLoggedIn = true,
                        userName = body.user.email
                    )
                } else {
                    _uiState.value = _uiState.value.copy(
                        isLoading = false,
                        error = "Invalid email or password"
                    )
                }
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    error = "Connection failed: ${e.localizedMessage}"
                )
            }
        }
    }

    fun signup(email: String, password: String) {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, error = null)
            try {
                val response = api.signup(SignupRequest(email, password))
                if (response.isSuccessful && response.body() != null) {
                    val body = response.body()!!
                    tokenManager.saveAuth(body.accessToken, body.user.id, body.user.email)
                    _uiState.value = _uiState.value.copy(
                        isLoading = false,
                        isLoggedIn = true,
                        userName = body.user.email
                    )
                } else {
                    _uiState.value = _uiState.value.copy(
                        isLoading = false,
                        error = "Signup failed — email may already be in use"
                    )
                }
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    error = "Connection failed: ${e.localizedMessage}"
                )
            }
        }
    }

    fun logout() {
        viewModelScope.launch {
            tokenManager.clearAll()
            _uiState.value = AuthUiState()
        }
    }

    fun clearError() {
        _uiState.value = _uiState.value.copy(error = null)
    }
}
