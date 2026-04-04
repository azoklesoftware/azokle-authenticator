package com.azokle.authenticator.ui.fragments.preferences;

import android.os.Bundle;

import com.azokle.authenticator.R;

public class MainPreferencesFragment extends PreferencesFragment {
    @Override
    public void onCreatePreferences(Bundle savedInstanceState, String rootKey) {
        addPreferencesFromResource(R.xml.preferences);
    }
}
