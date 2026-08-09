package com.azokle.authenticator.ui.fragments.preferences;

import android.graphics.Rect;
import android.os.Bundle;
import android.view.View;
import android.widget.LinearLayout;

import androidx.annotation.NonNull;
import androidx.core.graphics.Insets;
import androidx.core.view.ViewCompat;
import androidx.core.view.WindowInsetsCompat;
import androidx.fragment.app.Fragment;
import androidx.lifecycle.LiveData;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;

import com.azokle.authenticator.R;
import com.azokle.authenticator.database.AuditLogEntry;
import com.azokle.authenticator.database.AuditLogRepository;
import com.azokle.authenticator.helpers.MetricsHelper;
import com.azokle.authenticator.ui.models.AuditLogEntryModel;
import com.azokle.authenticator.ui.views.AuditLogAdapter;
import com.azokle.authenticator.vault.VaultEntry;
import com.azokle.authenticator.vault.VaultManager;

import java.util.List;
import java.util.UUID;

import javax.inject.Inject;

import dagger.hilt.android.AndroidEntryPoint;

@AndroidEntryPoint
public class AuditLogPreferencesFragment extends Fragment {

    @Inject
    AuditLogRepository _auditLogRepository;

    private AuditLogAdapter _adapter;

    private RecyclerView _auditLogRecyclerView;
    private LinearLayout _noAuditLogsView;

    @Inject
    VaultManager _vaultManager;

    public AuditLogPreferencesFragment() {
        super(R.layout.fragment_audit_log);
    }

    @Override
    public void onViewCreated(@NonNull View view, Bundle savedInstanceState) {
        LiveData<List<AuditLogEntry>> entries = _auditLogRepository.getAllAuditLogEntries();

        _adapter = new AuditLogAdapter();
        _noAuditLogsView = view.findViewById(R.id.vEmptyList);
        _auditLogRecyclerView = view.findViewById(R.id.list_audit_log);
        LinearLayoutManager layoutManager = new LinearLayoutManager(requireContext());
        _auditLogRecyclerView.addItemDecoration(new SpacesItemDecoration(8));
        _auditLogRecyclerView.setLayoutManager(layoutManager);
        _auditLogRecyclerView.setAdapter(_adapter);
        _auditLogRecyclerView.setNestedScrollingEnabled(false);

        ViewCompat.setOnApplyWindowInsetsListener(_auditLogRecyclerView, (targetView, windowInsets) -> {
            Insets insets = windowInsets.getInsets(WindowInsetsCompat.Type.systemBars() | WindowInsetsCompat.Type.displayCutout());
            targetView.setPadding(
                    0,
                    0,
                    0,
                    insets.bottom
            );
            return WindowInsetsCompat.CONSUMED;
        });

        entries.observe(getViewLifecycleOwner(), entries1 -> {
            _noAuditLogsView.setVisibility(entries1.isEmpty() ? View.VISIBLE : View.GONE);

            for (AuditLogEntry entry : entries1) {
                VaultEntry referencedEntry = null;
                if (entry.getReference() != null) {
                    UUID referencedEntryUUID = UUID.fromString(entry.getReference());
                    if (_vaultManager.getVault().hasEntryByUUID(referencedEntryUUID)) {
                        referencedEntry = _vaultManager.getVault().getEntryByUUID(referencedEntryUUID);
                    }
                }

                AuditLogEntryModel auditLogEntryModel = new AuditLogEntryModel(entry, referencedEntry);
                _adapter.addAuditLogEntryModel(auditLogEntryModel);
            }
        });
    }

    private class SpacesItemDecoration extends RecyclerView.ItemDecoration {
        private final int _space;

        public SpacesItemDecoration(int dpSpace) {
            _space = MetricsHelper.convertDpToPixels(getContext(), dpSpace);
        }

        @Override
        public void getItemOffsets(Rect outRect, View view, RecyclerView parent, RecyclerView.State state) {
            outRect.left = _space;
            outRect.right = _space;
            outRect.bottom = _space;

            if (parent.getChildLayoutPosition(view) == 0) {
                outRect.top = _space;
            }
        }
    }
}
