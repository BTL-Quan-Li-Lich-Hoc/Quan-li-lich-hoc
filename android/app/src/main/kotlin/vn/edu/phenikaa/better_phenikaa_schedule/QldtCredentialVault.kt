package vn.edu.phenikaa.better_phenikaa_schedule

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import org.json.JSONObject
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/** Opt-in credentials for the user's own QLĐT sign-in, encrypted only on this device. */
internal object QldtCredentialVault {
    data class Credentials(val username: String, val password: String)

    private const val PREFERENCES = "qldt_auto_login_private"
    private const val ENTRY = "encrypted_credentials"
    private const val KEY_ALIAS = "better_phenikaa_qldt_auto_login_v1"
    private const val CIPHER = "AES/GCM/NoPadding"

    fun save(context: Context, username: String, password: String): Boolean {
        val account = username.trim()
        require(account.isNotEmpty() && account.length <= 256)
        require(password.isNotEmpty() && password.length <= 512)
        val cipher = Cipher.getInstance(CIPHER).apply { init(Cipher.ENCRYPT_MODE, key()) }
        val plaintext = JSONObject().put("username", account)
            .put("password", password).toString().toByteArray(Charsets.UTF_8)
        val encrypted = cipher.doFinal(plaintext)
        val encoded = Base64.encodeToString(cipher.iv + encrypted, Base64.NO_WRAP)
        return context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
            .edit().putString(ENTRY, encoded).commit()
    }

    fun read(context: Context): Credentials? {
        val preferences = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
        val encoded = preferences.getString(ENTRY, null) ?: return null
        return try {
            val bytes = Base64.decode(encoded, Base64.NO_WRAP)
            require(bytes.size > 12 + 16)
            val cipher = Cipher.getInstance(CIPHER).apply {
                init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(128, bytes.copyOfRange(0, 12)))
            }
            val data = JSONObject(String(cipher.doFinal(bytes.copyOfRange(12, bytes.size)),
                Charsets.UTF_8))
            Credentials(data.getString("username"), data.getString("password"))
        } catch (_: Exception) {
            // Restored app data cannot decrypt against a device-bound Keystore key.
            preferences.edit().remove(ENTRY).commit()
            null
        }
    }

    fun clear(context: Context) {
        context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
            .edit().remove(ENTRY).commit()
    }

    private fun key(): SecretKey {
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (store.getKey(KEY_ALIAS, null) as? SecretKey)?.let { return it }
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
        generator.init(KeyGenParameterSpec.Builder(KEY_ALIAS,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setKeySize(256)
            .build())
        return generator.generateKey()
    }
}
