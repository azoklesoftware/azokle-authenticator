//
//  PassReminderService.swift
//  Azokle Auth
//
//  Created by Azokle.
//

import Foundation
import Combine

public enum PassReminderFrequency: String, CaseIterable, Identifiable {
    case never = "Never"
    case daily = "Daily"
    case weekly = "Weekly"
    case biweekly = "Every 2 Weeks"
    case monthly = "Monthly"

    public var id: String { rawValue }

    public var durationSeconds: TimeInterval {
        switch self {
        case .never: return Double.infinity
        case .daily: return 86400
        case .weekly: return 7 * 86400
        case .biweekly: return 14 * 86400
        case .monthly: return 30 * 86400
        }
    }
}

public final class PassReminderService: ObservableObject {
    public static let shared = PassReminderService()

    private let keyTimestamp = "pref_password_reminder_timestamp"
    private let keyFrequency = "pref_password_reminder_freq"

    @Published public var frequency: PassReminderFrequency {
        didSet {
            UserDefaults.standard.set(frequency.rawValue, forKey: keyFrequency)
        }
    }

    private init() {
        let saved = UserDefaults.standard.string(forKey: keyFrequency) ?? PassReminderFrequency.biweekly.rawValue
        self.frequency = PassReminderFrequency(rawValue: saved) ?? .biweekly

        if UserDefaults.standard.double(forKey: keyTimestamp) == 0 {
            recordSuccess()
        }
    }

    public var isReminderDue: Bool {
        guard frequency != .never else { return false }
        let lastTimestamp = UserDefaults.standard.double(forKey: keyTimestamp)
        guard lastTimestamp > 0 else { return false }
        let elapsed = Date().timeIntervalSince1970 - lastTimestamp
        return elapsed >= frequency.durationSeconds
    }

    public func recordSuccess() {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: keyTimestamp)
    }

    public func verify(password: String) -> Bool {
        guard let vault = VaultManager.shared.repository?.vaultFile else { return false }

        // Find a PasswordSlot in the vault header
        guard let passwordSlot = vault.header.slots.first(where: { $0.type == .password }) else {
            return false
        }

        do {
            _ = try passwordSlot.unlock(credential: password)
            recordSuccess()
            return true
        } catch {
            return false
        }
    }
}
