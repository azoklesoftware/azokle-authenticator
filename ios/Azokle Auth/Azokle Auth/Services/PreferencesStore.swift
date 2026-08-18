//
//  PreferencesStore.swift
//  Azokle Auth
//
//  Created by Azokle.
//

import SwiftUI
import Combine

public enum ViewMode: String, CaseIterable, Identifiable {
    case normal = "Normal"
    case compact = "Compact"
    case small = "Small"
    case tiles = "Tiles Grid"

    public var id: String { rawValue }
}

public enum SortOrder: String, CaseIterable, Identifiable {
    case custom = "Custom Order"
    case alphabetical = "Alphabetical (A-Z)"
    case usage = "Most Used"
    case lastUsed = "Recently Used"

    public var id: String { rawValue }
}

public enum CodeGrouping: String, CaseIterable, Identifiable {
    case none = "None (123456)"
    case half = "Half (123 456)"
    case pairs = "Pairs (12 34 56)"

    public var id: String { rawValue }
}

public enum AccountNamePosition: String, CaseIterable, Identifiable {
    case belowIssuer = "Below Issuer"
    case besideIssuer = "Beside Issuer"
    case onlyWhenNecessary = "Only When Necessary"

    public var id: String { rawValue }
}

public enum CopyBehavior: String, CaseIterable, Identifiable {
    case singleTap = "Single Tap"
    case doubleTap = "Double Tap"
    case tapToRevealOnly = "Tap to Reveal Only"

    public var id: String { rawValue }
}

public final class PreferencesStore: ObservableObject {
    public static let shared = PreferencesStore()

    @AppStorage("pref_view_mode") public var viewMode: ViewMode = .normal
    @AppStorage("pref_sort_order") public var sortOrder: SortOrder = .custom
    @AppStorage("pref_code_grouping") public var codeGrouping: CodeGrouping = .half
    @AppStorage("pref_account_name_position") public var accountNamePosition: AccountNamePosition = .belowIssuer
    @AppStorage("pref_copy_behavior") public var copyBehavior: CopyBehavior = .singleTap
    @AppStorage("pref_tap_to_reveal") public var tapToReveal: Bool = false
    @AppStorage("pref_tap_to_reveal_seconds") public var tapToRevealSeconds: Int = 10
    @AppStorage("pref_show_next_code") public var showNextCode: Bool = false
    @AppStorage("pref_focus_search") public var focusSearchOnLaunch: Bool = false
    @AppStorage("pref_auto_lock_seconds") public var autoLockSeconds: Int = 0 // 0 = immediately on minimize
    @AppStorage("pref_privacy_mask") public var privacyScreenMask: Bool = true
    @AppStorage("pref_auto_backup_enabled") public var autoBackupEnabled: Bool = true
    @AppStorage("pref_auto_backup_versions") public var autoBackupVersionCount: Int = 10
    @AppStorage("pref_search_in_issuer") public var searchInIssuer: Bool = true
    @AppStorage("pref_search_in_name") public var searchInName: Bool = true
    @AppStorage("pref_search_in_notes") public var searchInNotes: Bool = true
    @AppStorage("pref_search_in_groups") public var searchInGroups: Bool = true

    private init() {}

    /// Formats an OTP string with the selected code grouping
    public func formatOTP(_ code: String) -> String {
        return Theme.formatCode(code, grouping: codeGrouping)
    }
}
