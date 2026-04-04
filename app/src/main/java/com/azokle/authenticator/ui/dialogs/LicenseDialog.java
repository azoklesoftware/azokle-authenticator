package com.azokle.authenticator.ui.dialogs;

import android.content.Context;

import com.azokle.authenticator.R;

public class LicenseDialog extends SimpleWebViewDialog {
    public LicenseDialog() {
        super(R.string.license);
    }

    public static LicenseDialog create() {
        return new LicenseDialog();
    }

    @Override
    protected String getContent(Context context) {
        String license = readAssetAsString(context, "LICENSE");
        String html = readAssetAsString(context, "license.html");
        return String.format(html, license, getBackgroundColor(), getTextColor());
    }
}
