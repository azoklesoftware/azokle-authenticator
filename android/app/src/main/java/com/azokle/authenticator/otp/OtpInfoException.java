package com.azokle.authenticator.otp;

public class OtpInfoException extends Exception {
    public OtpInfoException(Throwable cause) {
        super(cause);
    }

    public OtpInfoException(String message) {
        super(message);
    }
}
