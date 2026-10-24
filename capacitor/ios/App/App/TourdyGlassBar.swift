import SwiftUI
import UIKit
import os

final class TourdyNavigationModel: ObservableObject {
    @Published var selected = "home"
    @Published var travelEnabled = true
    @Published var locked = false
    @Published var modal = false
    @Published var dark = false
    @Published var systemTheme = true
    @Published var ready = false
    let bridgeController = TourdyBridgeViewController()
    private var revision = -1
    private var request = 0
    private var confirmedTab = "home"
    private var session = ""

    init() { bridgeController.navigationModel = self }
    func select(_ tab: String) {
        guard !locked, !modal, ["home", "todo", "stats", "travel", "set"].contains(tab), tab != "travel" || travelEnabled else { return }
        selected = tab
        request += 1
        let currentRequest = request
        let script = "window.TourdyNative.navigationRequest=\(currentRequest); window.TourdySelectTab('\(tab)'); window.TourdyNative.navigationChanged();"
        bridgeController.webView?.evaluateJavaScript(script) { [weak self] _, error in
            guard let self, self.request == currentRequest, error != nil else { return }
            self.selected = self.confirmedTab
        }
    }
    func receive(tab: String, travelEnabled: Bool, locked: Bool, modal: Bool, dark: Bool, systemTheme: Bool, revision: Int, request: Int, session: String) {
        if session != self.session { self.session = session; self.revision = -1; self.request = 0 }
        guard revision > self.revision else { return }
        self.revision = revision
        ready = true
        self.travelEnabled = travelEnabled
        self.locked = locked
        self.modal = modal
        self.dark = dark
        self.systemTheme = systemTheme
        // A response from an earlier tap cannot undo a later native selection.
        if request >= self.request { confirmedTab = tab; selected = tab }
    }
}

struct TourdyNativeTabs: View {
    @ObservedObject var model: TourdyNavigationModel
    @State private var introVisible = true
    private let tabs = [("home", "홈", "house"), ("todo", "할 일", "checkmark.square"),
                        ("stats", "대시보드", ""), ("travel", "여행", "airplane"), ("set", "설정", "gearshape")]
    var body: some View {
        ZStack {
            systemTabs.allowsHitTesting(!introVisible && model.ready).accessibilityHidden(introVisible || !model.ready)
            if introVisible {
                TourdyIntro { withAnimation(.easeOut(duration: 0.22)) { introVisible = false } }
                    .transition(.opacity).zIndex(1)
            } else if !model.ready {
                ZStack {
                    Color(uiColor: .systemBackground).ignoresSafeArea()
                    VStack(spacing: 18) {
                        Text("TOURDY").font(.system(size: 30, weight: .bold, design: .rounded)).tracking(5)
                        ProgressView("여행을 준비하고 있어요").font(.caption)
                    }
                }.zIndex(1)
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    @ViewBuilder private var systemTabs: some View {
        if #available(iOS 16.0, *) {
            tabView.toolbar(model.modal || introVisible || !model.ready ? .hidden : .visible, for: .tabBar)
        } else { tabView }
    }
    private var tabView: some View {
        // System TabView: no custom capsule, material, or glass overlay.
        TabView(selection: Binding(get: { model.selected }, set: { model.select($0) })) {
            ForEach(tabs.filter { $0.0 != "travel" || model.travelEnabled }, id: \.0) { tab in
                TourdyTabPane(bridge: model.bridgeController, active: model.selected == tab.0)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea(edges: .bottom)
                    .tabItem {
                        if tab.0 == "stats" { Image(uiImage: dashboardImage); Text(tab.1) }
                        else { Label(tab.1, systemImage: tab.2) }
                    }
                    .tag(tab.0)
            }
        }
        .disabled(model.locked || introVisible || !model.ready)
        .preferredColorScheme(model.systemTheme ? nil : (model.dark ? .dark : .light))
    }
    private var dashboardImage: UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 25, height: 25)).image { _ in
            UIColor.black.setStroke()
            for rect in [CGRect(x: 1, y: 1, width: 9, height: 23), CGRect(x: 14, y: 1, width: 10, height: 8), CGRect(x: 14, y: 13, width: 10, height: 11)] {
                let path = UIBezierPath(roundedRect: rect, cornerRadius: 2)
                path.lineWidth = 1.8; path.stroke()
            }
        }.withRenderingMode(.alwaysTemplate)
    }
}

// All system tabs share one retained Capacitor controller and WKWebView.
private struct TourdyTabPane: UIViewControllerRepresentable {
    let bridge: TourdyBridgeViewController
    let active: Bool
    func makeUIViewController(context: Context) -> PaneController { PaneController() }
    func updateUIViewController(_ pane: PaneController, context: Context) {
        pane.configure(bridge: bridge, active: active)
    }
    static func dismantleUIViewController(_ pane: PaneController, coordinator: ()) { pane.detach() }
}

private final class PaneController: UIViewController {
    private weak var hosted: TourdyBridgeViewController?
    private var active = false
    func configure(bridge: TourdyBridgeViewController, active: Bool) {
        hosted = bridge
        self.active = active
        if active { attachIfVisible() } else { detach() }
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        attachIfVisible()
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        attachIfVisible()
    }
    private func attachIfVisible() {
        guard active, isViewLoaded, view.window != nil, let bridge = hosted else { return }
        guard bridge.parent !== self else { return }
        bridge.willMove(toParent: nil)
        bridge.view.removeFromSuperview(); bridge.removeFromParent()
        addChild(bridge)
        bridge.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bridge.view)
        NSLayoutConstraint.activate([
            bridge.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bridge.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bridge.view.topAnchor.constraint(equalTo: view.topAnchor),
            bridge.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        bridge.didMove(toParent: self)
        Logger(subsystem: "app.tourdy.navigation", category: "content").info("Attached retained web content to visible tab")
    }
    func detach() {
        // Old-pane teardown must not remove a bridge already moved to a new pane.
        guard let bridge = hosted, bridge.parent === self else { return }
        bridge.willMove(toParent: nil); bridge.view.removeFromSuperview(); bridge.removeFromParent()
    }
}

final class TourdyTabsViewController: UIHostingController<TourdyNativeTabs> {
    init() { super.init(rootView: TourdyNativeTabs(model: TourdyNavigationModel())) }
    @available(*, unavailable) required dynamic init?(coder aDecoder: NSCoder) { fatalError("Use the programmatic TabView root") }
}
