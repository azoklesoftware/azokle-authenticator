package com.azokle.authenticator.receivers;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

import com.azokle.authenticator.BuildConfig;
import com.azokle.authenticator.Preferences;
import com.azokle.authenticator.vault.VaultManager;

import javax.inject.Inject;

import dagger.hilt.android.AndroidEntryPoint;

@AndroidEntryPoint
public class VaultLockReceiver extends BroadcastReceiver {
    public static final String ACTION_LOCK_VAULT
            = String.format("%s.LOCK_VAULT", BuildConfig.APPLICATION_ID);

    @Inject
    protected VaultManager _vaultManager;

    @Override
    public void onReceive(Context context, Intent intent) {
        if (intent.getAction() == null
                || (!intent.getAction().equals(ACTION_LOCK_VAULT)
                && !intent.getAction().equals(Intent.ACTION_SCREEN_OFF))) {
            return;
        }

        if (_vaultManager.isAutoLockEnabled(Preferences.AUTO_LOCK_ON_DEVICE_LOCK)) {
            _vaultManager.lock(false);
        }
    }
}
