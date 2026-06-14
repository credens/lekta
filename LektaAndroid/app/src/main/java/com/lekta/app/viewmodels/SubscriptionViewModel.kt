package com.lekta.app.viewmodels

import androidx.lifecycle.ViewModel
import com.lekta.app.models.SubscriptionTier
import com.lekta.app.services.SecurePrefs
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import javax.inject.Inject

@HiltViewModel
class SubscriptionViewModel @Inject constructor(
    private val securePrefs: SecurePrefs
) : ViewModel() {

    private val _tier = MutableStateFlow(SubscriptionTier.FREE)
    val tier: StateFlow<SubscriptionTier> = _tier

    private val storageKey = "subscription_tier_v1"

    init { load() }

    fun canAddProduct(currentCount: Int): Boolean = currentCount < _tier.value.maxProducts

    fun productsRemaining(currentCount: Int): Int =
        (_tier.value.maxProducts - currentCount).coerceAtLeast(0)

    fun setTier(newTier: SubscriptionTier) {
        _tier.value = newTier
        save()
    }

    private fun load() {
        _tier.value = securePrefs.loadEncrypted<SubscriptionTier>(storageKey) ?: SubscriptionTier.FREE
    }

    private fun save() {
        securePrefs.saveEncrypted(storageKey, _tier.value)
    }
}
