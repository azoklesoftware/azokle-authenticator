package com.azokle.authenticator.importers;

import static java.nio.charset.StandardCharsets.UTF_8;

import android.content.Context;
import android.content.pm.PackageManager.NameNotFoundException;

import androidx.annotation.NonNull;

import com.azokle.authenticator.encoding.Base32;
import com.azokle.authenticator.encoding.EncodingException;
import com.azokle.authenticator.otp.HotpInfo;
import com.azokle.authenticator.otp.OtpInfo;
import com.azokle.authenticator.otp.OtpInfoException;
import com.azokle.authenticator.otp.TotpInfo;
import com.azokle.authenticator.util.IOUtils;
import com.azokle.authenticator.vault.VaultEntry;
import com.topjohnwu.superuser.io.SuFile;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.io.IOException;
import java.io.InputStream;

public class DuoImporter extends DatabaseImporter {
    private static final String _pkgName = "com.duosecurity.duomobile";
    private static final String _subPath = "files/duokit/accounts.json";

    public DuoImporter(Context context) {
        super(context);
    }

    @Override
    protected @NonNull SuFile getAppPath() throws DatabaseImporterException, NameNotFoundException {
        return getAppPath(_pkgName, _subPath);
    }

    @Override
    protected @NonNull State read(
            @NonNull InputStream stream, boolean isInternal
    ) throws DatabaseImporterException {
        try {
            String contents = new String(IOUtils.readAll(stream), UTF_8);
            return new DecryptedState(new JSONArray(contents));
        } catch (JSONException | IOException e) {
            throw new DatabaseImporterException(e);
        }
    }

    public static class DecryptedState extends DatabaseImporter.State {
        private final JSONArray _array;

        public DecryptedState(@NonNull JSONArray array) {
            super(false);
            _array = array;
        }

        @Override
        public @NonNull Result convert() throws DatabaseImporterException {
            Result result = new Result();

            try {
                for (int i = 0; i < _array.length(); i++) {
                    JSONObject entry = _array.getJSONObject(i);
                    try {
                        result.addEntry(convertEntry(entry));
                    } catch (DatabaseImporterEntryException e) {
                        result.addError(e);
                    }
                }
            } catch (JSONException e) {
                throw new DatabaseImporterException(e);
            }

            return result;
        }

        private static @NonNull VaultEntry convertEntry(
                @NonNull JSONObject entry
        ) throws DatabaseImporterEntryException {
            try {
                String label = entry.optString("name");
                JSONObject otpData = entry.getJSONObject("otpGenerator");
                byte[] secret = Base32.decode(otpData.getString("otpSecret"));
                Long counter = otpData.has("counter") ? otpData.getLong("counter") : null;

                OtpInfo otp = counter == null
                        ? new TotpInfo(secret)
                        : new HotpInfo(secret, counter);

                return new VaultEntry(otp, label, "");
            } catch (JSONException | OtpInfoException | EncodingException e) {
                throw new DatabaseImporterEntryException(e, entry.toString());
            }
        }
    }
}
