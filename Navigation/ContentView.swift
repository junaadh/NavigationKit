//
//  ContentView.swift
//  Navigation
//
//  Created by Moosa Junad on 15/11/2025.
//

import SwiftUI
import UIKit

struct ContentView: View {
    @Environment(\.router) private var router

    @State var title: String = ""
    @State var title2: String = ""

    var body: some View {
        RoutedTabView(router: router, selectionType: AppTab.self) {
            RoutedTab(
                AppTab.home,
                title: AppTab.home.description,
                systemName: AppTab.home.symbol
            ) {
                home
            }

            RoutedTab(
                AppTab.profile,
                title: AppTab.profile.description,
                systemName: AppTab.profile.symbol
            ) {
                Text("Profile")
            }

            RoutedTab(
                AppTab.setting,
                title: AppTab.setting.description,
                systemName: AppTab.setting.symbol
            ) {
                Text("Setting")
            }
        }
    }

    var home: some View {
        VStack {
            VStack {
                Image(systemName: "globe")
                    .imageScale(.large)
                    .foregroundStyle(.tint)
                Text("Hello, world!")
            }
            .contentShape(RoundedRectangle(cornerRadius: 12))
            .onTapGesture {
                router.push {
                    Text("page")
                        .onTapGesture {
                            //                            router.presentSheet(
                            router.push(
                                marker: "list",
                                {
                                    Text("page2")
                                        .onTapGesture {
                                            router.push {
                                                //                                            router.presentSheet {
                                                VStack {
                                                    Text("page3")
                                                        .onTapGesture {
                                                            router.push {
                                                                Text("page4")
                                                                    .onTapGesture
                                                                {
                                                                    router
                                                                        .push {
                                                                            Text(
                                                                                "page4"
                                                                            )
                                                                            .onTapGesture
                                                                            {

                                                                                router
                                                                                    .pop(
                                                                                        to:
                                                                                            "list"
                                                                                    )
                                                                            }
                                                                        }
                                                                }
                                                            }
                                                        }

                                                }
                                            }

                                        }
                                },
                                //                                style: .fullScreenCover
                            )
                        }
                }
            }
            .padding()

            NavLink(title: "Title", systemName: "trash") {
                MenuView(title: $title)
            }

            NavLink {
                MenuView2 {
                    title2 = $0
                }
            } label: {
                Text("Title2: \(title2)")
            }
        }
    }
}

struct MenuView: View {
    @Environment(\.router) private var router
    @Binding var title: String

    var body: some View {
        HStack {
            TextField("Title", text: $title, prompt: Text("Enter title"))
        }

        Button("Done") {
            router.pop()
        }
        .buttonStyle(.borderedProminent)
    }
}

struct MenuView2: View {
    @Environment(\.router) private var router
    let onDone: (String) -> Void

    @State private var title: String = ""

    var body: some View {
        HStack {
            TextField("Title", text: $title, prompt: Text("Enter title"))
        }

        Button("Done") {
            onDone(title)
            router.pop()
        }
        .buttonStyle(.borderedProminent)
    }
}

#Preview {
    NavStack {
        ContentView()
    }
}

protocol TabViewable: CaseIterable, CustomStringConvertible {
    @ViewBuilder
    var label: Label<Text, Image> { get }
}

enum AppTab: Hashable, TabViewable {
    case home, profile, setting

    var description: String {
        switch self {
        case .home:
            "Home"
        case .profile:
            "Profile"
        case .setting:
            "Setting"
        }
    }

    var symbol: String {
        switch self {
        case .home:
            "house"
        case .profile:
            "person"
        case .setting:
            "gearshape"
        }
    }

    var label: Label<Text, Image> {
        Label(self.description, systemImage: self.symbol)
    }
}

enum SheetStyle {
    case sheet(
        detents: [SheetDetents] = [.medium, .large]
    )
    case fullScreenCover

    enum SheetDetents {
        case medium, large, height(_: CGFloat)

        var uiKit: UISheetPresentationController.Detent {
            switch self {
            case .medium:
                .medium()
            case .large:
                .large()
            case .height(let height):
                .custom(resolver: { _ in height })
            }
        }
    }
}

/// Core UIKit engine for navigation
final class NavigationEngine: NSObject, UINavigationControllerDelegate {
    private let navigationController: UINavigationController
    private weak var router: Router?
    private let rootVC: UIHostingController<AnyView>

    private var sheets: [UIViewController] = []
    private var markers: [UIViewController: String] = [:]

    init(rootView: AnyView) {
        self.rootVC = UIHostingController(rootView: rootView)
        self.navigationController = UINavigationController(
            rootViewController: rootVC
        )

        super.init()
        navigationController.delegate = self
    }

    func setRouter(_ router: Router) {
        self.router = router
        self.rootVC.rootView = AnyView(
            self.rootVC.rootView.environment(self.router)
        )
    }

    func getController() -> UINavigationController { navigationController }

    func push<V: View>(
        _ view: V,
        marker: String? = nil,
        animated: Bool = true,
        dismiss dismissTopSheets: Bool = true
    ) {
        guard let router else {
            assertionFailure("Router not set in NavigationEngine")
            return
        }

        if dismissTopSheets, let topSheet = sheets.last {
            topSheet.dismiss(animated: false)
            sheets.removeLast()
        }

        let vc = UIHostingController(rootView: view.environment(router))
        if let marker {
            markers[vc] = marker
        }
        vc.hidesBottomBarWhenPushed = false  // <- keeps the tab bar
        navigationController.pushViewController(vc, animated: animated)
    }

    func pop(animated: Bool = true) {
        guard let top = navigationController.topViewController else { return }
        markers[top] = nil
        navigationController.popViewController(animated: animated)
    }

    func popToRoot(animated: Bool = true) {
        markers.removeAll()
        navigationController.popToRootViewController(animated: animated)
    }

    func pop(to marker: String, animated: Bool = true) {
        // find the last VC with this marker
        guard
            let targetVC = navigationController.viewControllers.last(where: {
                markers[$0] == marker
            })
        else {
            return
        }
        // remove all markers above
        navigationController.viewControllers
            .filter {
                $0 != targetVC
                    && navigationController.viewControllers.firstIndex(of: $0)!
                        > navigationController.viewControllers.firstIndex(
                            of: targetVC
                        )!
            }
            .forEach { markers[$0] = nil }

        navigationController.popToViewController(targetVC, animated: animated)
    }

    func presentSheet<V: View>(
        _ view: V,
        style: SheetStyle = .sheet(),
        allowStacking: Bool = true
    ) {
        let controller = UIHostingController(rootView: view)

        switch style {
        case .sheet(let detents):
            controller.modalPresentationStyle = .pageSheet
            if let sheetController = controller.sheetPresentationController {
                sheetController.detents = detents.map { $0.uiKit }
            }

            if !allowStacking, let topSheet = sheets.last {
                topSheet.dismiss(animated: false)
                sheets.removeLast()
            }
        case .fullScreenCover:
            controller.modalPresentationStyle = .fullScreen
        }

        sheets.append(controller)
        let presenter = topMostPresentableViewController(
            allowSheetsOnFullScreen: allowStacking
        )
        presenter?.present(controller, animated: true)
    }

    func dismissSheet(animated: Bool = true) {
        guard let sheet = sheets.popLast() else { return }
        sheet.dismiss(animated: animated)
    }

    func dismissAllSheets(animated: Bool = true) {
        for sheet in sheets.reversed() {
            sheet.dismiss(animated: animated)
        }
        sheets.removeAll()
    }

    private func topMostPresentableViewController(allowSheetsOnFullScreen: Bool)
        -> UIViewController?
    {
        var top = navigationController.topViewController
        while let presented = top?.presentedViewController {
            if presented.modalPresentationStyle == .fullScreen,
                !allowSheetsOnFullScreen
            {
                // cannot present sheet on full screen
                return top
            }
            top = presented
        }
        return top
    }
}

@MainActor
@Observable
class Router {
    weak var parent: Router?
    weak var child: Router?

    private(set) var tabType: Any.Type?
    private(set) var tabs: [AnyHashable] = []
    var currentTab: AnyHashable?

    // Reference to internal UITabBarController if this router owns tabs
    fileprivate weak var tabController: RoutedTabBarController?

    private let engine: NavigationEngine

    init(engine: NavigationEngine) {
        self.engine = engine
        self.engine.setRouter(self)
    }

    func registerTabs<T: CaseIterable & Hashable>(for tabsType: T.Type) {
        self.tabType = tabsType
        self.tabs = T.allCases.map { $0 }
        self.currentTab = tabs.first
    }

    func switchTab<T: Hashable>(_ tab: T) {
        // If this router owns the tab type, switch
        if tabType == T.self {
            currentTab = tab
        } else {
            // Otherwise propagate to parent
            parent?.switchTab(tab)
        }
    }

    static func closest(to env: EnvironmentValues) -> Router {
        env[RouterKey.self]
    }

    func push<V: View>(
        marker: String? = nil,
        dismiss: Bool = true,
        @ViewBuilder _ content: () -> V
    ) {
        engine.push(content(), marker: marker, dismiss: dismiss)
    }

    func pop() { engine.pop() }
    func popToRoot() { engine.popToRoot() }
    func pop(to marker: String) { engine.pop(to: marker) }

    func presentSheet<V: View>(
        @ViewBuilder _ content: () -> V,
        style: SheetStyle = .sheet(),
        allowStacking: Bool = true
    ) {
        engine.presentSheet(
            content(),
            style: style,
            allowStacking: allowStacking
        )
    }

    func dismissSheet() {
        engine.dismissSheet()
    }

    func dismissAllSheet() {
        engine.dismissAllSheets()
    }
}

struct NavStack: View {
    @State private var router: Router
    private let engine: NavigationEngine

    init(@ViewBuilder _ content: () -> some View) {
        self.engine = NavigationEngine(rootView: AnyView(content()))
        _router = State(initialValue: Router(engine: engine))
    }

    var body: some View {
        ZStack {
            NavigationControllerContainer(engine: engine)
                .edgesIgnoringSafeArea(.all)
        }
        .environment(\.router, router)
    }
}

struct NavigationControllerContainer: UIViewControllerRepresentable {
    let engine: NavigationEngine

    func makeUIViewController(context: Context) -> UINavigationController {
        engine.getController()
    }

    func updateUIViewController(
        _ uiViewController: UINavigationController,
        context: Context
    ) {}
}

private struct RouterKey: EnvironmentKey {
    static let defaultValue: Router = Router(
        engine: NavigationEngine(rootView: AnyView(EmptyView()))
    )
}

extension EnvironmentValues {
    var router: Router {
        get { self[RouterKey.self] }
        set { self[RouterKey.self] = newValue }
    }
}

struct NavLink<Label: View, Destination: View>: View {
    @Environment(\.router) private var router

    @ViewBuilder var destination: () -> Destination
    @ViewBuilder var label: () -> Label

    init(
        @ViewBuilder _ destination: @escaping () -> Destination,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.destination = destination
        self.label = label
    }

    init(
        label: String,
        @ViewBuilder _ destination: @escaping () -> Destination
    ) where Label == Text {
        self.destination = destination
        self.label = { Text(label) }
    }

    init(
        title: String,
        systemName: String,
        @ViewBuilder destination: @escaping () -> Destination
    ) where Label == SwiftUI.Label<Text, Image> {
        self.destination = destination
        self.label = { SwiftUI.Label(title, systemImage: systemName) }
    }

    var body: some View {
        AnyView(label())
            .contentShape(Capsule())
            .onTapGesture {
                router.push {
                    destination()
                }
            }
    }
}

// MARK: - RoutedTabView Builder

@resultBuilder
struct RoutedTabBuilder {
    static func buildBlock(_ components: RoutedTab...)
        -> [RoutedTab]
    {
        components
    }
}

// MARK: - RoutedTabView SwiftUI wrapper

struct RoutedTabView<Selection: Hashable>: View where Selection: CaseIterable {
    @State private var router: Router
    let selectionType: Selection.Type
    let tabs: [RoutedTab]

    init(
        router: Router,
        selectionType: Selection.Type,
        @RoutedTabBuilder content: () -> [RoutedTab]
    ) {
        self._router = State(initialValue: router)
        self.selectionType = selectionType
        self.tabs = content()
        router.registerTabs(for: selectionType)
        router.tabController = nil  // will be set in representable
    }

    var body: some View {
        RoutedTabBarControllerRepresentable(
            router: router,
            tabs: tabs
        )
        .environment(\.router, router)
    }
}

// MARK: - Single Tab definition

struct RoutedTab: Identifiable {
    let id = UUID()
    let tab: AnyHashable
    let title: String
    let systemName: String
    let content: AnyView

    init<T: View>(
        _ tab: AnyHashable,
        title: String,
        systemName: String,
        @ViewBuilder content: () -> T
    ) {
        self.tab = tab
        self.title = title
        self.systemName = systemName
        self.content = AnyView(content())
    }
}

// MARK: - UIKit Tab Controller wrapper

final class RoutedTabBarController: UITabBarController {
    var router: Router!
    var tabMap: [AnyHashable: UINavigationController] = [:]

    func `switch`(to tab: AnyHashable?) {
        guard let tab else { return }
        if let nav = tabMap[tab] {
            self.selectedViewController = nav
        }
    }

    init(router: Router, tabs: [RoutedTab]) {
        super.init(nibName: nil, bundle: nil)
        self.router = router
        router.tabController = self

        var viewControllers: [UINavigationController] = []
        for tabItem in tabs {
            let navController = UINavigationController(
                rootViewController: UIHostingController(
                    rootView: tabItem.content
                )
            )
            navController.tabBarItem = UITabBarItem(
                title: tabItem.title,
                image: UIImage(systemName: tabItem.systemName),
                tag: 0
            )
            tabMap[tabItem.tab] = navController
            viewControllers.append(navController)
        }

        self.setViewControllers(viewControllers, animated: false)
    }

    required init?(coder: NSCoder) { fatalError() }
}

// MARK: - Representable

struct RoutedTabBarControllerRepresentable: UIViewControllerRepresentable {
    let router: Router
    let tabs: [RoutedTab]

    func makeUIViewController(context: Context) -> RoutedTabBarController {
        RoutedTabBarController(router: router, tabs: tabs)
    }

    func updateUIViewController(
        _ uiViewController: RoutedTabBarController,
        context: Context
    ) {
        // Could handle dynamic tab changes here if needed
    }
}
