package com.azokle.authenticator.importers;

public class DatabaseImporterException extends Exception {
    public DatabaseImporterException(Throwable cause) {
        super(cause);
    }

    public DatabaseImporterException(String message) {
        super(message);
    }
}
