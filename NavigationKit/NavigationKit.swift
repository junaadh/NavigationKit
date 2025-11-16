//
//  NavigationKit.swift
//  NavigationKit
//
//  Created by Moosa Junad on 16/11/2025.
//

import SwiftUI
import UIKit

// ---------- Environment keys ----------
private struct RouterKey: EnvironmentKey {
    static let defaultValue: Router = {
        let engine = NavigationEngine(rootView: AnyView(EmptyView()))
        return Router(engine: engine)
    }()
}

extension EnvironmentValues {
    var router: Router {
        get { self[RouterKey.self] }
        set { self[RouterKey.self] = newValue }
    }

    private struct NavigationCoordinatorKey: EnvironmentKey {
        static let defaultValue: NavigationCoordinator? = nil
    }

    var navigationCoordinator: NavigationCoordinator? {
        get { self[NavigationCoordinatorKey.self] }
        set { self[NavigationCoordinatorKey.self] = newValue }
    }
}

// ---------- Coordinator (uses @Observable) ----------
@Observable
final class NavigationCoordinator {
    let router: Router
    let engine: NavigationEngine
    var viewID = UUID()  // trigger UI updates

    init(rootView: some View) {
        let engine = NavigationEngine(rootView: AnyView(EmptyView()))
        self.engine = engine
        self.router = Router(engine: engine)
        engine.setRouter(self.router)

        // Now inject the actual root view with router
        let rootWithRouter = AnyView(rootView.environment(\.router, router))
        engine.setRootView(rootWithRouter)
    }

    func registerTabs<Selection: Hashable & CaseIterable>(
        _ selectionType: Selection.Type,
        style: TabBarStyle,
        tabs: [RoutedTab]
    ) {
        print("Coordinator.registerTabs called")
        router.registerTabs(for: selectionType, style: style, content: tabs)
        viewID = UUID()  // force UI update
    }
}

// ---------- Public Swift API: NavStack ----------
public struct NavStack<Root: View>: View {
    @State private var coordinator: NavigationCoordinator

    public init(@ViewBuilder _ content: @escaping () -> Root) {
        _coordinator = State(
            wrappedValue: NavigationCoordinator(rootView: content())
        )
    }

    public var body: some View {
        NavigationControllerContainer(
            engine: coordinator.engine,
            viewID: coordinator.viewID
        )
        .edgesIgnoringSafeArea(.all)
        .environment(\.router, coordinator.router)
        .environment(\.navigationCoordinator, coordinator)
    }
}

// ---------- Router (Swift / SwiftUI facing API) ----------
@MainActor
@Observable
final class Router {
    fileprivate weak var engine: NavigationEngine?

    private(set) var tabType: Any.Type?
    private(set) var tabs: [AnyHashable] = []
    var currentTab: AnyHashable?

    // Track environment values to propagate
    private var environmentValues: EnvironmentValues?

    init(engine: NavigationEngine) {
        self.engine = engine
        engine.setRouter(self)
    }

    func registerTabs<T: CaseIterable & Hashable>(
        for tabsType: T.Type,
        style: TabBarStyle = .system,
        content: [RoutedTab]
    ) {
        print("Router.registerTabs called with type: \(tabsType)")
        self.tabType = tabsType
        self.tabs = content.map { $0.tab }
        self.currentTab = self.tabs.first
        print(
            "Router configured - tabType: \(String(describing: self.tabType)), tabs: \(self.tabs.count)"
        )
        engine?.registerTabs(content, style: style, router: self)
    }

    func switchTab<T: Hashable>(_ tab: T) {
        guard tabType == T.self else {
            print(
                "Warning: Trying to switch to tab of type \(T.self) but router is configured for \(String(describing: tabType))"
            )
            return
        }
        currentTab = tab
        engine?.switchTab(to: tab)
    }

    func push<V: View>(
        marker: String? = nil,
        hideBottomBar: Bool = false,
        @ViewBuilder _ content: @escaping () -> V
    ) {
        guard let engine = engine else { return }
        // Create the view and inject router - DON'T wrap in AnyView here
        let view = content().environment(\.router, self)
        engine.push(
            view,
            marker: marker,
            hideBottomBar: hideBottomBar
        )
    }

    func pop() { engine?.pop() }
    func popToRoot() { engine?.popToRoot() }
    func pop(to marker: String) { engine?.pop(to: marker) }

    func presentSheet<V: View>(
        style: SheetStyle = .sheet(),
        allowStacking: Bool = true,
        @ViewBuilder _ content: @escaping () -> V
    ) {
        guard let engine = engine else { return }
        // Create the view and inject router - DON'T wrap in AnyView here
        let v = content().environment(\.router, self)
        engine.presentSheet(
            v,
            style: style,
            allowStacking: allowStacking
        )
    }

    func dismissSheet() { engine?.dismissSheet() }
    func dismissAllSheets() { engine?.dismissAllSheets() }
}

// ---------- Navigation engine (UIKit owner) ----------
final class NavigationEngine: NSObject, UINavigationControllerDelegate,
    UITabBarControllerDelegate
{
    private(set) var rootNav: UINavigationController
    private weak var router: Router?

    private var tabHost: TabHostController?
    private var markers: [UINavigationController: [UIViewController: String]] =
        [:]
    private var sheets: [UIViewController] = []

    init(rootView: AnyView) {
        self.rootNav = UINavigationController(
            rootViewController: UIHostingController(rootView: rootView)
        )
        super.init()
        rootNav.delegate = self
    }

    func setRouter(_ router: Router) {
        self.router = router
    }

    func setRootView(_ view: AnyView) {
        // Replace the root view controller with the properly configured one
        if let root = rootNav.viewControllers.first
            as? UIHostingController<AnyView>
        {
            root.rootView = view
        }
    }

    func getController() -> UIViewController {
        return tabHost ?? rootNav
    }

    private var currentNav: UINavigationController {
        tabHost?.selectedNav ?? rootNav
    }

    private var currentMarkers: [UIViewController: String] {
        get { markers[currentNav] ?? [:] }
        set { markers[currentNav] = newValue }
    }

    func push<V: View>(
        _ view: V,
        marker: String? = nil,
        animated: Bool = true,
        hideBottomBar: Bool = false
    ) {
        if let topSheet = sheets.last {
            topSheet.dismiss(animated: true)
            sheets.removeLast()
        }

        // Wrap in AnyView only when creating the UIHostingController
        // This preserves the view's identity and state
        let hosted = UIHostingController(rootView: AnyView(view))

        if let marker {
            var m = currentMarkers
            m[hosted] = marker
            currentMarkers = m
        }
        hosted.hidesBottomBarWhenPushed = hideBottomBar

        print(
            "Pushing view controller, current nav stack: \(currentNav.viewControllers.count)"
        )
        currentNav.pushViewController(hosted, animated: animated)
    }

    func pop() {
        if let top = currentNav.topViewController {
            var m = currentMarkers
            m[top] = nil
            currentMarkers = m
        }
        currentNav.popViewController(animated: true)
    }

    func popToRoot() {
        currentMarkers = [:]
        currentNav.popToRootViewController(animated: true)
    }

    func pop(to marker: String) {
        guard
            let target = currentNav.viewControllers.last(where: {
                currentMarkers[$0] == marker
            })
        else {
            return
        }

        /*
        currentNav.viewControllers.filter {
            $0 != target
                && currentNav.viewControllers.firstIndex(of: $0)! > currentNav
                    .viewControllers.firstIndex(of: target)!
        }
        .forEach {
            var m = currentMarkers
            m[$0] = nil
            currentMarkers = m
        }
         */
        let idx = currentNav.viewControllers.firstIndex(of: target)
        let vcsToRemoveMarkers = currentNav.viewControllers.suffix(
            from: idx! + 1
        )
        var newMarkers = currentMarkers
        for vc in vcsToRemoveMarkers {
            newMarkers[vc] = nil
        }
        currentMarkers = newMarkers

        // TODO: - This is janky
        for _ in 0...(currentNav.viewControllers.count - idx!) - 1 {
            currentNav.popViewController(animated: true)
        }
//        currentNav.popToViewController(target, animated: true)
    }

    func presentSheet<V: View>(
        _ view: V,
        style: SheetStyle = .sheet(),
        allowStacking: Bool = true
    ) {
        let controller = UIHostingController(rootView: AnyView(view))

        switch style {
        case .sheet(let detents):
            controller.modalPresentationStyle = .pageSheet
            if let sheetController = controller.sheetPresentationController {
                sheetController.detents = detents.map { $0.uiKit }
            }
            if !allowStacking, let top = sheets.last {
                top.dismiss(animated: false)
                sheets.removeLast()
            }
        case .fullScreenCover:
            controller.modalPresentationStyle = .fullScreen
        }
        sheets.append(controller)
        topMostPresentable?.present(controller, animated: true)
    }

    func dismissSheet() {
        sheets.popLast()?.dismiss(animated: true)
    }

    func dismissAllSheets() {
        sheets.reversed().forEach { $0.dismiss(animated: true) }
        sheets.removeAll()
    }

    private var topMostPresentable: UIViewController? {
        var top = currentNav.topViewController
        while let p = top?.presentedViewController { top = p }
        return top
    }

    func registerTabs(_ tabs: [RoutedTab], style: TabBarStyle, router: Router) {
        guard tabHost == nil else { return }
        let host = TabHostController(tabs: tabs, style: style, router: router)
        host.delegate = self
        tabHost = host
        router.currentTab = tabs.first?.tab
    }

    func switchTab(to tab: AnyHashable) {
        tabHost?.switch(to: tab)
    }

    func tabBarController(
        _ tabBarController: UITabBarController,
        didSelect viewController: UIViewController
    ) {
        guard let host = tabHost, let nav = host.selectedNav,
            let selected = host.tabMap.first(where: { $0.value === nav })?.key
        else { return }
        router?.currentTab = selected
    }
}

// ---------- Supporting enums and protocols ----------
public enum SheetStyle {
    case sheet(detents: [SheetDetent] = [.medium, .large])
    case fullScreenCover
}

public enum SheetDetent {
    case medium, large
    case height(CGFloat)
    fileprivate var uiKit: UISheetPresentationController.Detent {
        switch self {
        case .medium: return .medium()
        case .large: return .large()
        case .height(let h): return .custom(resolver: { _ in h })
        }
    }
}

public enum TabBarStyle {
    case system
    case hidden
    case custom(UIKitTabBarProvider)
}

public protocol UIKitTabBarProvider {
    func makeTabBar() -> UITabBar
}

// ---------- RoutedTab ----------
public struct RoutedTab: Identifiable {
    public let id = UUID()
    public let tab: AnyHashable
    public let title: String
    public let systemName: String
    // Store the builder and create UIHostingController directly
    private let makeHostingController: (Router) -> UIViewController

    public init<T: View>(
        _ tab: AnyHashable,
        title: String,
        systemName: String,
        @ViewBuilder content: @escaping () -> T
    ) {
        self.tab = tab
        self.title = title
        self.systemName = systemName
        // Capture the builder and preserve the generic type
        self.makeHostingController = { router in
            UIHostingController(
                rootView: content().environment(\.router, router)
            )
        }
    }

    func createViewController(with router: Router) -> UIViewController {
        makeHostingController(router)
    }
}

// ---------- TabHostController ----------
final class TabHostController: UITabBarController {
    var tabMap: [AnyHashable: UINavigationController] = [:]
    private var customProvider: UIKitTabBarProvider?
    private var style: TabBarStyle
    private weak var router: Router?

    var selectedNav: UINavigationController? {
        selectedViewController as? UINavigationController
    }

    init(tabs: [RoutedTab], style: TabBarStyle, router: Router) {
        self.style = style
        self.router = router
        super.init(nibName: nil, bundle: nil)

        var vcs: [UINavigationController] = []
        for tab in tabs {
            // Create the hosting controller - it returns UIViewController
            let rootHosting = tab.createViewController(with: router)
            let nav = UINavigationController(rootViewController: rootHosting)
            nav.delegate = router.engine
            nav.tabBarItem = UITabBarItem(
                title: tab.title,
                image: UIImage(systemName: tab.systemName),
                selectedImage: UIImage(systemName: "\(tab.systemName).fill")
            )
            tabMap[tab.tab] = nav
            vcs.append(nav)
        }

        setViewControllers(vcs, animated: false)
        applyStyle(style)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    func `switch`(to tab: AnyHashable) {
        guard let nav = tabMap[tab] else { return }
        selectedViewController = nav
    }

    private func applyStyle(_ style: TabBarStyle) {
        switch style {
        case .system:
            if customProvider != nil {
                restoreDefaultTabBar()
                customProvider = nil
            }
            tabBar.isHidden = false
        case .hidden:
            tabBar.isHidden = true
            tabBar.setNeedsLayout()
            tabBar.alpha = 0
        case .custom(let provider):
            customProvider = provider
            let custom = provider.makeTabBar()
            setValue(custom, forKey: "tabBar")
            view.setNeedsLayout()
        }
    }

    private func restoreDefaultTabBar() {
        let bar = UITabBar()
        setValue(bar, forKey: "tabBar")
    }
}

// ---------- UI wrapper for NavigationEngine ----------
struct NavigationControllerContainer: UIViewControllerRepresentable {
    let engine: NavigationEngine
    let viewID: UUID

    internal func makeUIViewController(context: Context)
        -> ContainerViewController
    {
        let container = ContainerViewController()
        container.setContent(engine.getController())
        return container
    }

    internal func updateUIViewController(
        _ uiViewController: ContainerViewController,
        context: Context
    ) {
        let new = engine.getController()

        // Only swap if the controller instance has actually changed
        if uiViewController.contentViewController !== new {
            uiViewController.setContent(new)
        }
    }

    // Container to properly manage view controller hierarchy
    internal class ContainerViewController: UIViewController {
        private(set) weak var contentViewController: UIViewController?

        func setContent(_ viewController: UIViewController) {
            // Remove old content if exists
            if let old = contentViewController {
                old.willMove(toParent: nil)
                old.view.removeFromSuperview()
                old.removeFromParent()
            }

            // Add new content
            addChild(viewController)
            view.addSubview(viewController.view)
            viewController.view.frame = view.bounds
            viewController.view.autoresizingMask = [
                .flexibleWidth, .flexibleHeight,
            ]
            viewController.didMove(toParent: self)

            contentViewController = viewController
        }
    }
}

// ---------- RoutedTabView (SwiftUI DSL) ----------
public struct RoutedTabView<Selection: Hashable & CaseIterable>: View {
    @Environment(\.navigationCoordinator) private var coordinator

    private let selectionType: Selection.Type
    private let style: TabBarStyle
    private let content: () -> [RoutedTab]

    public init(
        for selectionType: Selection.Type,
        style: TabBarStyle = .system,
        @RoutedTabBuilder content: @escaping () -> [RoutedTab]
    ) {
        self.selectionType = selectionType
        self.style = style
        self.content = content
    }

    public var body: some View {
        Color.clear
            .onAppear {
                guard let coord = coordinator else {
                    print(
                        "ERROR: NavigationCoordinator missing from environment"
                    )
                    return
                }
                coord.registerTabs(selectionType, style: style, tabs: content())
            }
            .frame(width: 0, height: 0)
    }
}

// ---------- Result builder for RoutedTab ----------
@resultBuilder
public struct RoutedTabBuilder {
    public static func buildBlock(_ components: RoutedTab...) -> [RoutedTab] {
        components
    }
}

// ---------- NavLink convenience ----------
public struct NavLink<Label: View, Destination: View>: View {
    @Environment(\.router) private var router
    private let label: () -> Label
    private let destination: () -> Destination

    public init(
        @ViewBuilder destination: @escaping () -> Destination,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.destination = destination
        self.label = label
    }

    public init(
        _ title: String,
        systemImage: String,
        @ViewBuilder destination: @escaping () -> Destination
    ) where Label == SwiftUI.Label<Text, Image> {
        self.destination = destination
        self.label = { SwiftUI.Label(title, systemImage: systemImage) }
    }

    public var body: some View {
        Button {
            // Create destination at tap time to capture current state
            router.push {
                destination()
            }
        } label: {
            label()
        }
    }
}
