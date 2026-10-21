package com.nox.app.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Link
import androidx.compose.material.icons.filled.PhoneAndroid
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.nox.app.ui.components.NoxButton
import com.nox.app.ui.components.NoxTextField
import com.nox.app.ui.theme.NoxColors

@Composable
fun AddDeviceDialog(
    onDismiss: () -> Unit,
    onAdd: (String) -> Unit
) {
    var deviceName by remember { mutableStateOf("") }

    AlertDialog(
        onDismissRequest = onDismiss,
        containerColor = NoxColors.DeepAbyss,
        shape = RoundedCornerShape(20.dp),
        title = {
            Text("Register Device", color = NoxColors.PureLight)
        },
        text = {
            Column {
                Text(
                    "Enter a name for this device. You'll get a pairing code to enter on the device.",
                    style = MaterialTheme.typography.bodyMedium,
                    color = NoxColors.ShadowPurple
                )
                Spacer(modifier = Modifier.height(16.dp))
                NoxTextField(
                    value = deviceName,
                    onValueChange = { deviceName = it },
                    label = "Device Name",
                    leadingIcon = Icons.Default.PhoneAndroid
                )
            }
        },
        confirmButton = {
            NoxButton(
                text = "Register",
                onClick = { onAdd(deviceName) },
                enabled = deviceName.isNotBlank(),
                modifier = Modifier.width(140.dp)
            )
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("Cancel", color = NoxColors.ShadowPurple)
            }
        }
    )
}

@Composable
fun PairDeviceDialog(
    onDismiss: () -> Unit,
    onPair: (String) -> Unit
) {
    var pairingCode by remember { mutableStateOf("") }

    AlertDialog(
        onDismissRequest = onDismiss,
        containerColor = NoxColors.DeepAbyss,
        shape = RoundedCornerShape(20.dp),
        title = {
            Text("Pair Device", color = NoxColors.PureLight)
        },
        text = {
            Column {
                Text(
                    "Enter the 6-character pairing code shown on the device you want to connect.",
                    style = MaterialTheme.typography.bodyMedium,
                    color = NoxColors.ShadowPurple
                )
                Spacer(modifier = Modifier.height(16.dp))
                NoxTextField(
                    value = pairingCode,
                    onValueChange = { pairingCode = it.uppercase() },
                    label = "Pairing Code",
                    leadingIcon = Icons.Default.Link
                )
            }
        },
        confirmButton = {
            NoxButton(
                text = "Pair",
                onClick = { onPair(pairingCode) },
                enabled = pairingCode.length == 6,
                modifier = Modifier.width(120.dp)
            )
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("Cancel", color = NoxColors.ShadowPurple)
            }
        }
    )
}
