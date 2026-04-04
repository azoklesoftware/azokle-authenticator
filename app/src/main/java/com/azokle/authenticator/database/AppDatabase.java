package com.azokle.authenticator.database;

import androidx.room.Database;
import androidx.room.RoomDatabase;

@Database(entities = {AuditLogEntry.class}, version = 1)
public abstract class AppDatabase extends RoomDatabase {
    public abstract AuditLogDao auditLogDao();
}