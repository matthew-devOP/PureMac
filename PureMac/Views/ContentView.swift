import SwiftUI

struct ContentView: View {
    @EnvironmentObject var vm: AppViewModel

    var body: some View {
        HStack(spacing: 0) {
            SidebarView()
                .frame(width: 220)

            Divider()
                .background(Color.pmSeparator)

            // Main content
            ZStack {
                Color.pmBackground
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Top bar with disk info
                    TopBarView()
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                        .padding(.bottom, 8)

                    // Content area
                    Group {
                        switch vm.selectedCategory {
                        case .smartScan:
                            SmartScanView()
                        default:
                            CategoryDetailView(category: vm.selectedCategory)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .background(Color.pmBackground)
        .onAppear {
            NSWindow.allowsAutomaticWindowTabbing = false
        }
    }
}

// MARK: - Top Bar

struct TopBarView: View {
    @EnvironmentObject var vm: AppViewModel

    var body: some View {
        HStack(spacing: 16) {
            // Disk usage indicator
            HStack(spacing: 12) {
                Image(systemName: "internaldrive.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.pmAccentLight)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Macintosh HD")
                        .font(.pmCaption)
                        .foregroundColor(.pmTextPrimary)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.pmCard)
                                .frame(height: 6)

                            RoundedRectangle(cornerRadius: 3)
                                .fill(
                                    vm.diskInfo.usedPercentage > 0.9 ? AppGradients.danger :
                                    vm.diskInfo.usedPercentage > 0.7 ? AppGradients.accent :
                                    AppGradients.success
                                )
                                .frame(width: geo.size.width * vm.diskInfo.usedPercentage, height: 6)
                        }
                    }
                    .frame(height: 6)
                }
                .frame(width: 160)

                Text("\(vm.diskInfo.formattedFree) free")
                    .font(.pmCaption)
                    .foregroundColor(.pmTextSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.pmCard.opacity(0.6))
            .cornerRadius(10)

            Spacer()

            // Schedule indicator
            if vm.scheduler.config.isEnabled {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.pmSuccess)
                        .frame(width: 6, height: 6)
                    Text("Auto-clean: \(vm.scheduler.config.interval.rawValue)")
                        .font(.pmCaption)
                        .foregroundColor(.pmTextSecondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.pmCard.opacity(0.6))
                .cornerRadius(8)
            }

            // Settings button
            Button(action: {
                if #available(macOS 14.0, *) {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                } else {
                    NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
                }
            }) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.pmTextSecondary)
                    .frame(width: 32, height: 32)
                    .background(Color.pmCard.opacity(0.6))
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
    }
}
