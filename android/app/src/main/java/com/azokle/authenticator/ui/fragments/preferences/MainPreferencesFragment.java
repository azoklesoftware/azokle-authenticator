package com.azokle.authenticator.ui.fragments.preferences;

import android.content.Intent;
import android.os.Bundle;

import androidx.annotation.NonNull;
import androidx.preference.Preference;

import com.azokle.authenticator.R;
import com.azokle.authenticator.ui.AboutActivity;

public class MainPreferencesFragment extends PreferencesFragment {
    @Override
    public void onCreatePreferences(Bundle savedInstanceState, String rootKey) {
        addPreferencesFromResource(R.xml.preferences);
    }

    @Override
    public boolean onPreferenceTreeClick(@NonNull Preference preference) {
        if ("pref_about".equals(preference.getKey())) {
            startActivity(new Intent(requireContext(), AboutActivity.class));
            return true;
        }
        return super.onPreferenceTreeClick(preference);
    }
}
