//
//  NavigationKit.swift
//  NavigationKit
//
//  Created by Moosa Junad on 16/11/2025.
//

import SwiftUI
import UIKit

// **************************************************************
// ******************** Public API ******************************
// **************************************************************

// MARK: Router View
/// A container view that provides UIKit-backed navigation with programmatic routing capabilities.
///
/// `RouterView` wraps your app's root content and enables navigation through the injected `Router` instance.
/// Use this as the top-level container in your app to enable programmatic navigation, tab management, and sheet presentation.
///
/// Example:
/// ```swift
/// @main
/// struct MyApp: App {
///     var body: some Scene {
///         WindowGroup {
///             RouterView {
///                 HomeView()
///             }
///         }
///     }
/// }
/// ```
public struct RouterView<Root: View>: View {
    @State private var coordinator: _NavigationCoordinator

    public init(@ViewBuilder _ content: @escaping () -> Root) {
        _coordinator = State(
            wrappedValue: _NavigationCoordinator(rootView: content())
        )
    }

    public var body: some View {
        _NavigationControllerContainer(
            engine: coordinator.engine,
            viewID: coordinator.viewID
        )
        .edgesIgnoringSafeArea(.all)
        .environment(\.router, coordinator.router)
        .environment(\.navigationCoordinator, coordinator)
    }
}

// MARK: - NavLink convenience

/// A button that navigates to a destination view when tapped.
///
/// `RouterLink` provides a declarative way to create navigation triggers in your UI.
/// It automatically uses the router from the environment to perform navigation.
///
/// Example:
/// ```swift
/// RouterLink {
///     DetailView(item: item)
/// } label: {
///     Text("View Details")
/// }
/// ```
public struct RouterLink<Label: View, Destination: View>: View {
    @Environment(\.router) private var router
    private let label: () -> Label
    private let destination: () -> Destination

    /// Creates a router link with custom label and destination.
    ///
    /// - Parameters:
    ///   - destination: A view builder that creates the destination view.
    ///   - label: A view builder that creates the link's label.
    public init(
        @ViewBuilder destination: @escaping () -> Destination,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.destination = destination
        self.label = label
    }

    /// Creates a router link with a text label and SF Symbol icon.
    ///
    /// - Parameters:
    ///   - title: The text to display in the label.
    ///   - systemImage: The SF Symbol name for the icon.
    ///   - destination: A view builder that creates the destination view.
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

// MARK: - TabRouter

/// A SwiftUI view that configures tab-based navigation.
///
/// Use `TabRouter` to define a tab bar interface with multiple tabs, each containing its own navigation stack.
/// Place this view inside your `RouterView` to enable tab-based navigation.
///
/// Example:
/// ```swift
/// enum AppTab: Hashable, CaseIterable {
///     case home, search, profile
/// }
///
/// RouterView {
///     TabRouter(for: AppTab.self, tabs: [
///         Route(.home, title: "Home", systemName: "house") {
///             HomeView()
///         },
///         Route(.search, title: "Search", systemName: "magnifyingglass") {
///             SearchView()
///         },
///         Route(.profile, title: "Profile", systemName: "person") {
///             ProfileView()
///         }
///     ])}
/// }
/// ```
public struct TabRouter<Selection: Hashable & CaseIterable>: View {
    @Environment(\.navigationCoordinator) private var coordinator

    private let selectionType: Selection.Type
    private let style: TabBarStyle
    private let content: [Route<Selection>]

    /// Creates a tab router with a result builder.
    ///
    /// - Parameters:
    ///   - selectionType: The type of the tab selection enum. Must conform to `Hashable` and `CaseIterable`.
    ///   - style: The visual style of the tab bar. Default is `.system`.
    ///   - content: A result builder that creates the array of routes.
    public init(
        for selectionType: Selection.Type,
        style: TabBarStyle = .automatic,
        @RouteBuilder content: @escaping () -> [Route<Selection>]
    ) {
        self.selectionType = selectionType
        self.style = style
        self.content = content()
    }

    /// Creates a tab router with an explicit array of routes.
    ///
    /// - Parameters:
    ///   - selectionType: The type of the tab selection enum. Must conform to `Hashable` and `CaseIterable`.
    ///   - style: The visual style of the tab bar. Default is `.system`.
    ///   - content: An array of routes defining each tab.
    public init(
        for selectionType: Selection.Type,
        style: TabBarStyle = .automatic,
        tabs content: [Route<Selection>]
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
                coord.registerTabs(selectionType, style: style, tabs: content)
            }
            .frame(width: 0, height: 0)
    }
}

// MARK: - Route

/// Represents a single tab in a tab-based navigation interface.
///
/// A `Route` defines the content, appearance, and identifier for a tab in your app's tab bar.
///
/// Example:
/// ```swift
/// Route(.home, title: "Home", systemName: "house") {
///     HomeView()
/// }
/// ```
public struct Route<S: Hashable>: Identifiable {
    public let id = UUID()
    public let tab: S
    public let title: String
    public let systemName: String
    // Store the builder and create UIHostingController directly
    private let makeHostingController: (Router) -> UIViewController

    public init<T: View>(
        _ tab: S,
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

// ---------- Environment keys ----------
private struct RouterKey: EnvironmentKey {
    static let defaultValue: Router = {
        let engine = _NavigationEngine(rootView: AnyView(EmptyView()))
        return Router(engine: engine)
    }()
}

extension EnvironmentValues {
    var router: Router {
        get { self[RouterKey.self] }
        set { self[RouterKey.self] = newValue }
    }

    private struct NavigationCoordinatorKey: EnvironmentKey {
        static let defaultValue: _NavigationCoordinator? = nil
    }

    var navigationCoordinator: _NavigationCoordinator? {
        get { self[NavigationCoordinatorKey.self] }
        set { self[NavigationCoordinatorKey.self] = newValue }
    }
}

// ---------- Coordinator (uses @Observable) ----------
@Observable
internal final class _NavigationCoordinator {
    let router: Router
    fileprivate let engine: _NavigationEngine
    var viewID = UUID()  // trigger UI updates

    init(rootView: some View) {
        let engine = _NavigationEngine(rootView: AnyView(EmptyView()))
        self.engine = engine
        self.router = Router(engine: engine)
        engine.setRouter(self.router)

        // Now inject the actual root view with router
        let rootWithRouter = AnyView(rootView.environment(\.router, router))
        engine.setRootView(rootWithRouter)
    }

    func registerTabs<Selection: Hashable>(
        _ selectionType: Selection.Type,
        style: TabBarStyle,
        tabs: [Route<Selection>]
    ) {
        print("Coordinator.registerTabs called")
        router.registerTabs(for: selectionType, style: style, content: tabs)
        viewID = UUID()  // force UI update
    }
}

// ---------- Router (Swift / SwiftUI facing API) ----------
@MainActor
@Observable
final class Router {
    fileprivate weak var engine: _NavigationEngine?

    private var tabsContainer: AnyTabsContainer?
    var currentTab: AnyHashable?

    // Track environment values to propagate
    private var environmentValues: EnvironmentValues?

    fileprivate init(engine: _NavigationEngine) {
        self.engine = engine
        engine.setRouter(self)
    }

    func registerTabs<T: Hashable>(
        for tabsType: T.Type,
        style: TabBarStyle = .automatic,
        content: [Route<T>]
    ) {
        print("Router.registerTabs called with type: \(tabsType)")
        self.tabsContainer = TabsContainer(tabs: content)
        self.currentTab = content.first?.tab
        print(
            "Router configured - tabs: \(content.count)"
        )
        engine?.registerTabs(content, style: style, router: self)
    }

    func switchTab<T: Hashable>(_ tab: T) {
        guard let container = tabsContainer as? TabsContainer<T> else {
            print(
                "Warning: Trying to switch to tab of type \(T.self) but router is configured for different type"
            )
            return
        }

        guard container.tabs.contains(where: { $0.tab == tab }) else {
            print("Warning: Tab \(tab) not found in registered tabs")
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
        detents: [SheetDetent] = [.medium, .large],
        allowStacking: Bool = true,
        @ViewBuilder _ content: @escaping () -> V
    ) {
        guard let engine = engine else { return }
        // Create the view and inject router - DON'T wrap in AnyView here
        let v = content().environment(\.router, self)
        engine.presentSheet(
            v,
            style: .sheet(detents: detents),
            allowStacking: allowStacking
        )
    }
    
    func presentFullScreen<V: View>(@ViewBuilder _ content: @escaping () -> V) {
        guard let engine = engine else { return }
        let v = content().environment(\.router, self)
        engine.presentSheet(
            v,
            style: .fullScreenCover,
            allowStacking: true
        )
    }

    func dismissSheet() { engine?.dismissSheet() }
    func dismissAllSheets() { engine?.dismissAllSheets() }
}

// ---------- Navigation engine (UIKit owner) ----------
internal final class _NavigationEngine: NSObject, UINavigationControllerDelegate,
    UITabBarControllerDelegate
{
    private(set) var rootNav: UINavigationController
    private weak var router: Router?

    private var tabHost: _TabHostController?
    private var markers: [ObjectIdentifier: String] = [:]
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
            markers[hosted.mark] = marker
        }

        hosted.hidesBottomBarWhenPushed = hideBottomBar

        print(
            "Pushing view controller, current nav stack: \(currentNav.viewControllers.count)"
        )
        currentNav.pushViewController(hosted, animated: animated)
    }

    func pop() {
        if let top = currentNav.topViewController {
            markers[top.mark] = nil
        }
        currentNav.popViewController(animated: true)
    }

    func popToRoot() {
        markers = [:]
        currentNav.popToRootViewController(animated: true)
    }

    func pop(to marker: String) {
        guard
            let target = currentNav.viewControllers.last(where: {
                markers[$0.mark] == marker
            })
        else {
            return
        }

        currentNav.viewControllers.filter {
            $0 != target
                && currentNav.viewControllers.firstIndex(of: $0)! > currentNav
                    .viewControllers.firstIndex(of: target)!
        }
        .forEach {
            markers[$0.mark] = nil
        }

        currentNav.popToViewController(target, animated: true)
    }

    fileprivate func presentSheet<V: View>(
        _ view: V,
        style: _SheetStyle,
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

    func registerTabs<S: Hashable>(
        _ tabs: [Route<S>],
        style: TabBarStyle,
        router: Router
    ) {
        guard tabHost == nil else { return }
        let host = _TabHostController(tabs: tabs, style: style, router: router)
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
fileprivate enum _SheetStyle {
    case sheet(detents: [SheetDetent])
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
    case automatic
    case hidden
    case custom(UIKitTabBarProvider)
}

public protocol UIKitTabBarProvider {
    func makeTabBar() -> UITabBar
}



// ---------- TabHostController ----------
internal final class _TabHostController: UITabBarController {
    var tabMap: [AnyHashable: UINavigationController] = [:]
    private var customProvider: UIKitTabBarProvider?
    private var style: TabBarStyle
    private weak var router: Router?

    var selectedNav: UINavigationController? {
        selectedViewController as? UINavigationController
    }

    init<S: Hashable>(tabs: [Route<S>], style: TabBarStyle, router: Router)
    {
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
        case .automatic:
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
internal struct _NavigationControllerContainer: UIViewControllerRepresentable {
    fileprivate let engine: _NavigationEngine
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

// ---------- Result builder for RoutedTab ----------
@resultBuilder
public struct RouteBuilder {
    public static func buildBlock<S>(_ components: Route<S>...)
        -> [Route<S>]
    {
        components
    }
}

// ---------- Tab Container ----------
private protocol AnyTabsContainer {
    // Empty protocol for type erasure
}

private struct TabsContainer<T: Hashable>: AnyTabsContainer {
    let tabs: [Route<T>]
}

// ----------- Ext UIViewController -------------
extension UIViewController {
    var mark: ObjectIdentifier {
        ObjectIdentifier(self)
    }
}
