package com.azokle.authenticator.encoding;

import java.io.IOException;

public class EncodingException extends IOException {
    public EncodingException(Throwable cause) {
        super(cause);
    }

    public EncodingException(String message) {
        super(message);
    }
}
