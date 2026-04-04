package com.azokle.authenticator.helpers.comparators;

import com.azokle.authenticator.vault.VaultEntry;

import java.util.Comparator;

public class UsageCountComparator implements Comparator<VaultEntry> {
    @Override
    public int compare(VaultEntry a, VaultEntry b) {
        return Integer.compare(a.getUsageCount(), b.getUsageCount());
    }
}