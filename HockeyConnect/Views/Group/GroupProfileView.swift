import SwiftUI

struct GroupProfileView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var showDeleteConfirm = false
    @State private var deleteError: String?

    var body: some View {
        NavigationStack {
            ZStack {
                IceBackground()
                ScrollView {
                    VStack(spacing: 20) {
                        ZStack {
                            Circle()
                                .fill(Color.iceBlue.opacity(0.2))
                                .frame(width: 90, height: 90)
                            Image(systemName: "person.3.fill")
                                .font(.system(size: 34))
                                .foregroundStyle(Color.iceBlue)
                        }
                        .padding(.top, 12)

                        Text(authVM.groupProfile?.groupName ?? "")
                            .font(.title2.bold())
                            .foregroundStyle(.primary)

                        Text("Phoenix Hockey Group")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        GlassCard {
                            VStack(spacing: 14) {
                                ProfileRow(label: "Contact", value: authVM.currentUser?.displayName ?? "")
                                ProfileRow(label: "Phone", value: authVM.currentUser?.phone ?? "")
                                ProfileRow(label: "Home Rink", value: authVM.groupProfile?.rinkName ?? "")
                                ProfileRow(label: "Address", value: authVM.groupProfile?.rinkAddress ?? "")
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
            .navigationTitle("Group Profile")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.hidden, for: .navigationBar)
            .alert("Delete Account?", isPresented: $showDeleteConfirm) {
                Button("Delete Permanently", role: .destructive) {
                    Task {
                        do {
                            try await authVM.deleteAccount()
                        } catch {
                            deleteError = "Couldn't delete. Sign out, sign in again, and try once more.\n\n\(error.localizedDescription)"
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently removes your group, posted games, and history. It can't be undone.")
            }
        }
    }
}
