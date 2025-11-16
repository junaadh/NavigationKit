import SwiftUI

// MARK: - Root with Tabs

struct RootView: View {
    var body: some View {
        RoutedTabView(for: AppTab.self) {
            //        TabContainer(AppTab.self) {
            RoutedTab(AppTab.home, title: "Home", systemName: "house") {
                HomeScreen()
            }

            RoutedTab(AppTab.profile, title: "Profile", systemName: "person") {
                ProfileScreen()
            }

            RoutedTab(
                AppTab.settings,
                title: "Settings",
                systemName: "gearshape"
            ) {
                SettingsScreen()
            }
        }
    }
}

enum AppTab: Hashable, CaseIterable {
    case home, profile, settings
}

#Preview {
    NavStack {
        RootView()
    }
}

// MARK: - Home Screen

struct HomeScreen: View {
    @Environment(\.router) private var router
    @State private var username: String = ""
    @State private var count: Int = 0

    var body: some View {
        VStack(spacing: 20) {
            Text("Home")
                .font(.largeTitle)

            Text("Count: \(count)")
                .font(.title2)

            Button("Increment") {
                count += 1
            }
            .buttonStyle(.borderedProminent)

            Divider()

            Text("Username: '\(username)'")
                .foregroundColor(.secondary)

            // Using NavigationLink
            NavLink("Edit Username", systemImage: "pencil") {
                EditUsernameScreen(username: $username)
            }

            // Using manual push
            Button("Push Details") {
                router.push {
                    DetailScreen(count: count)
                }
            }

            Button("Show Sheet") {
                router.presentSheet {
                    SheetContent()
                }
            }

            Button("Go to Profile") {
                router.switchTab(AppTab.profile)
            }
        }
        .padding()
        .onChange(of: username) { old, new in
            print("Username changed: \(old) -> \(new)")
        }
    }
}

// MARK: - Edit Username Screen

struct EditUsernameScreen: View {
    @Environment(\.router) private var router
    @Binding var username: String

    var body: some View {
        VStack(spacing: 20) {
            Text("Edit Username")
                .font(.title)

            TextField("Username", text: $username)
                .textFieldStyle(.roundedBorder)
                .padding()

            Text("Current: '\(username)'")
                .font(.caption)
                .foregroundColor(.secondary)

            Button("Done") {
                router.pop()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

// MARK: - Detail Screen

struct DetailScreen: View {
    @Environment(\.router) private var router
    let count: Int

    var body: some View {
        VStack(spacing: 20) {
            Text("Detail")
                .font(.title)

            Text("Count from previous screen: \(count)")

            Button("Push Another") {
                router.push(marker: "detail") {
                    ThirdScreen()
                }
            }

            Button("Pop") {
                router.pop()
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
}

// MARK: - Third Screen

struct ThirdScreen: View {
    @Environment(\.router) private var router

    var body: some View {
        VStack(spacing: 20) {
            Text("Third Screen")
                .font(.title)

            Button("Pop to Detail") {
                router.pop(to: "detail")
            }

            Button("Pop to Root") {
                router.popToRoot()
            }
        }
        .padding()
    }
}

// MARK: - Sheet Content

struct SheetContent: View {
    @Environment(\.router) private var router

    var body: some View {
        VStack(spacing: 20) {
            Text("Sheet")
                .font(.title)

            Button("Dismiss") {
                router.dismissSheet()
            }
            .buttonStyle(.borderedProminent)

            Button("Show Full Screen") {
                router.presentSheet(style: .fullScreenCover) {
                    FullScreenContent()
                }
            }
        }
        .padding()
    }
}

// MARK: - Full Screen Content

struct FullScreenContent: View {
    @Environment(\.router) private var router

    var body: some View {
        ZStack {
            Color.blue.ignoresSafeArea()

            VStack(spacing: 20) {
                Text("Full Screen Cover")
                    .font(.title)
                    .foregroundColor(.white)

                Button("Dismiss") {
                    router.dismissSheet()
                }
                .buttonStyle(.borderedProminent)

                Button("Dismiss All") {
                    router.dismissAllSheets()
                }
                .buttonStyle(.bordered)
            }
        }
    }
}

// MARK: - Profile Screen

struct ProfileScreen: View {
    @Environment(\.router) private var router

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 80))

            Text("Profile")
                .font(.largeTitle)

            Button("Go to Home") {
                router.switchTab(AppTab.home)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

// MARK: - Settings Screen

struct SettingsScreen: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 80))

            Text("Settings")
                .font(.largeTitle)
        }
        .padding()
    }
}
