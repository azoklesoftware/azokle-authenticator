package com.azokle.authenticator.otp;

import static org.junit.Assert.assertEquals;

import com.azokle.authenticator.crypto.otp.MOTPTest;
import com.azokle.authenticator.encoding.EncodingException;
import com.azokle.authenticator.encoding.Hex;

import org.junit.Test;

public class MotpInfoTest {
    @Test
    public void testMotpInfoOtp() throws OtpInfoException, EncodingException {
        for (MOTPTest.Vector vector : MOTPTest.VECTORS) {
            MotpInfo info = new MotpInfo(Hex.decode(vector.Secret), vector.Pin);
            assertEquals(vector.OTP, info.getOtp(vector.Time));
        }
    }
}
