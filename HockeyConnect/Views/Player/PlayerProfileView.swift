import SwiftUI

struct PlayerProfileView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var showEdit = false
    @State private var showDeleteConfirm = false
    @State private var deleteError: String?

    var body: some View {
        NavigationStack {
            ZStack {
                IceBackground()
                ScrollView {
                    VStack(spacing: 20) {
                        // Avatar — shows first+last initials (e.g. "JS")
                        ZStack {
                            Circle()
                                .fill(Color.iceBlue.opacity(0.2))
                                .frame(width: 90, height: 90)
                            Text(initials(for: authVM.currentUser?.displayName ?? ""))
                                .font(.system(size: 34, weight: .bold))
                                .foregroundStyle(Color.iceBlue)
                        }
                        .padding(.top, 12)

                        Text(authVM.currentUser?.displayName ?? "")
                            .font(.title2.bold())
                            .foregroundStyle(.primary)

                        if let profile = authVM.playerProfile {
                            HStack(spacing: 8) {
                                SkillBadge(level: profile.skillLevel)
                                PositionPill(profile: profile)
                            }
                        }

                        Button {
                            showEdit = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "pencil")
                                Text("Edit Profile")
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.iceBlue)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(Color.iceBlue.opacity(0.12), in: Capsule())
                        }

                        GlassCard {
                            VStack(spacing: 14) {
                                ProfileRow(label: "Phone", value: authVM.currentUser?.phone ?? "")
                                if let profile = authVM.playerProfile {
                                    ProfileRow(label: "Age", value: "\(profile.age)")
                                    ProfileRow(label: "Skill", value: "\(profile.skillLevel) — \(profile.skillLabel)")
                                    ProfileRow(label: "Position", value: positionDescription(for: profile))
                                    ProfileRow(label: "Available windows", value: "\(profile.availability.count) set")
                                }
                            }
                            .padding(20)
                        }
                        .padding(.horizontal, 16)

                        Button(role: .destructive) {
                            authVM.signOut()
                        } label: {
                            Text("Sign Out")
                                .foregroundStyle(.red.opacity(0.8))
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.red.opacity(0.4), lineWidth: 1))
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                        // App Store guideline 5.1.1(v): in-app account deletion.
                        Button {
                            showDeleteConfirm = true
                        } label: {
                            Text("Delete Account")
                                .font(.subheadline)
                                .foregroundStyle(.red)
                                .underline()
                        }
                        .padding(.top, 4)

                        if let err = deleteError {
                            Text(err)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .padding(.horizontal, 24)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.hidden, for: .navigationBar)
            .sheet(isPresented: $showEdit) {
                EditPlayerProfileSheet()
                    .environmentObject(authVM)
            }
            .alert("Delete Account?", isPresented: $showDeleteConfirm) {
                Button("Delete Permanently", role: .destructive) {
                    Task {
                        do {
                            try await authVM.deleteAccount()
                        } catch {
                            // Firebase requires recent sign-in for account
                            // deletion — surface that to the user clearly.
                            deleteError = "Couldn't delete. Sign out, sign in again, and try once more.\n\n\(error.localizedDescription)"
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently removes your profile, availability, and game history. It can't be undone.")
            }
        }
    }

    /// Human-readable position summary, e.g. "Forward (also plays D)".
    private func positionDescription(for profile: PlayerProfile) -> String {
        switch profile.primaryPosition {
        case .goalie: return "Goalie"
        case .forward:
            return profile.playsBothWays ? "Forward (also plays D)" : "Forward only"
        case .defense:
            return profile.playsBothWays ? "Defense (also plays forward)" : "Defense only"
        }
    }

    /// Returns first+last initials from a full name, falling back to a single
    /// initial or "?" if the name is empty.
    private func initials(for name: String) -> String {
        let parts = name
            .split(separator: " ")
            .map { String($0) }
            .filter { !$0.isEmpty }
        guard let first = parts.first?.first else { return "?" }
        if parts.count >= 2, let last = parts.last?.first {
            return String([first, last]).uppercased()
        }
        return String(first).uppercased()
    }
}

// MARK: - Small position pill shown next to skill badge

struct PositionPill: View {
    let profile: PlayerProfile

    private var color: Color {
        switch profile.primaryPosition {
        case .forward: return Color(red: 0.94, green: 0.51, blue: 0.20)
        case .defense: return Color(red: 0.20, green: 0.55, blue: 0.78)
        case .goalie:  return Color(red: 0.46, green: 0.36, blue: 0.78)
        }
    }

    private var text: String {
        let base = profile.primaryPosition.label
        return (profile.primaryPosition != .goalie && profile.playsBothWays)
            ? "\(base) + flex"
            : base
    }

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color, in: Capsule())
    }
}

// MARK: - Edit sheet (name + skill level + position)

struct EditPlayerProfileSheet: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var skillLevel: Int = 3
    @State private var position: Position = .forward
    @State private var playsBothWays: Bool = false
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            ZStack {
                IceBackground()
                ScrollView {
                    VStack(spacing: 20) {
                        GlassCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Name")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.secondary)
                                TextField("Full name", text: $name)
                                    .padding(12)
                                    .background(Color.black.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
                                    .foregroundStyle(.primary)
                            }
                            .padding(20)
                        }
                        .padding(.horizontal, 16)

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Position")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 4)

                            HStack(spacing: 8) {
                                ForEach(Position.allCases, id: \.self) { p in
                                    Button {
                                        withAnimation(.spring(response: 0.25)) {
                                            position = p
                                            if p == .goalie { playsBothWays = false }
                                        }
                                    } label: {
                                        Text(p.label)
                                            .font(.subheadline.weight(.medium))
                                            .foregroundStyle(position == p ? .white : .primary)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                            .background(position == p ? Color.iceBlue : Color.white,
                                                        in: RoundedRectangle(cornerRadius: 10))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .stroke(position == p ? Color.iceBlue : Color.black.opacity(0.1),
                                                            lineWidth: position == p ? 2 : 1)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }

                            if position != .goalie {
                                Toggle("Also play \(position == .forward ? "defense" : "forward")",
                                       isOn: $playsBothWays)
                                    .toggleStyle(SwitchToggleStyle(tint: Color.iceBlue))
                                    .font(.subheadline.weight(.medium))
                                    .padding(.top, 4)
                            }
                        }
                        .padding(.horizontal, 16)

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Skill Level")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 4)

                            VStack(spacing: 10) {
                                ForEach(SkillTier.all, id: \.level) { tier in
                                    Button {
                                        withAnimation(.spring(response: 0.3)) {
                                            skillLevel = tier.level
                                        }
                                    } label: {
                                        HStack(spacing: 14) {
                                            ZStack {
                                                Circle()
                                                    .fill(tier.color.opacity(skillLevel == tier.level ? 1.0 : 0.18))
                                                    .frame(width: 40, height: 40)
                                                Text("\(tier.level)")
                                                    .font(.headline.bold())
                                                    .foregroundStyle(skillLevel == tier.level ? .white : tier.color)
                                            }
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(tier.title)
                                                    .font(.subheadline.weight(.semibold))
                                                    .foregroundStyle(.primary)
                                                Text(tier.blurb)
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                                    .multilineTextAlignment(.leading)
                                            }
                                            Spacer()
                                            if skillLevel == tier.level {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundStyle(tier.color)
                                            }
                                        }
                                        .padding(12)
                                        .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14)
                                                .stroke(skillLevel == tier.level ? tier.color : Color.black.opacity(0.08),
                                                        lineWidth: skillLevel == tier.level ? 2 : 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .padding(.top, 10)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving…" : "Save") { save() }
                        .disabled(isSaving || name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                name = authVM.currentUser?.displayName ?? ""
                skillLevel = authVM.playerProfile?.skillLevel ?? 3
                position = authVM.playerProfile?.primaryPosition ?? .forward
                playsBothWays = authVM.playerProfile?.playsBothWays ?? false
            }
        }
    }

    private func save() {
        isSaving = true
        Task {
            let trimmed = name.trimmingCharacters(in: .whitespaces)
            if trimmed != authVM.currentUser?.displayName {
                await authVM.updateDisplayName(trimmed)
            }
            if skillLevel != authVM.playerProfile?.skillLevel {
                await authVM.updateSkillLevel(skillLevel)
            }
            if position != authVM.playerProfile?.primaryPosition
                || playsBothWays != authVM.playerProfile?.playsBothWays {
                await authVM.updatePosition(position, playsBothWays: playsBothWays)
            }
            isSaving = false
            dismiss()
        }
    }
}
