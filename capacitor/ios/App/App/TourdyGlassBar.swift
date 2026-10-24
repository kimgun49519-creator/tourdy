import SwiftUI
import UIKit

final class TourdyNavigationModel: ObservableObject {
    @Published var selected = "home"
    @Published var travelEnabled = true
    @Published var locked = false
    @Published var modal = false
    @Published var dark = false
    let bridgeController = TourdyBridgeViewController()
    private var revision = -1
    private var request = 0
    private var confirmedTab = "home"

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
    func receive(tab: String, travelEnabled: Bool, locked: Bool, modal: Bool, dark: Bool, revision: Int, request: Int) {
        guard revision > self.revision else { return }
        self.revision = revision
        self.travelEnabled = travelEnabled
        self.locked = locked
        self.modal = modal
        self.dark = dark
        // A response from an earlier tap cannot undo a later native selection.
        if request >= self.request { confirmedTab = tab; selected = tab }
    }
}

struct TourdyNativeTabs: View {
    @ObservedObject var model: TourdyNavigationModel
    private let tabs = [("home", "홈", "house"), ("todo", "할 일", "checkmark.square"),
                        ("stats", "대시보드", ""), ("travel", "여행", "airplane"), ("set", "설정", "gearshape")]
    var body: some View {
        if #available(iOS 16.0, *) {
            tabView.toolbar(model.modal ? .hidden : .visible, for: .tabBar)
        } else { tabView }
    }
    private var tabView: some View {
        // System TabView: no custom capsule, material, or glass overlay.
        TabView(selection: Binding(get: { model.selected }, set: { model.select($0) })) {
            ForEach(tabs.filter { $0.0 != "travel" || model.travelEnabled }, id: \.0) { tab in
                TourdyTabPane(bridge: model.bridgeController, active: model.selected == tab.0)
                    .ignoresSafeArea(edges: .bottom)
                    .tabItem {
                        if tab.0 == "stats" { Image(uiImage: dashboardImage); Text(tab.1) }
                        else { Label(tab.1, systemImage: tab.2) }
                    }
                    .tag(tab.0)
            }
        }
        .disabled(model.locked)
        .preferredColorScheme(model.dark ? .dark : .light)
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
        if active { pane.attach(bridge) } else { pane.detach() }
    }
    static func dismantleUIViewController(_ pane: PaneController, coordinator: ()) { pane.detach() }
}

private final class PaneController: UIViewController {
    private weak var hosted: TourdyBridgeViewController?
    func attach(_ bridge: TourdyBridgeViewController) {
        guard bridge.parent !== self else { return }
        bridge.willMove(toParent: nil)
        bridge.view.removeFromSuperview(); bridge.removeFromParent()
        hosted = bridge
        addChild(bridge)
        bridge.view.frame = view.bounds
        bridge.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(bridge.view)
        bridge.didMove(toParent: self)
    }
    func detach() {
        // Old-pane teardown must not remove a bridge already moved to a new pane.
        guard let bridge = hosted, bridge.parent === self else { return }
        bridge.willMove(toParent: nil); bridge.view.removeFromSuperview(); bridge.removeFromParent()
    }
}

@objc(TourdyTabsViewController)
final class TourdyTabsViewController: UIHostingController<TourdyNativeTabs> {
    init() { super.init(rootView: TourdyNativeTabs(model: TourdyNavigationModel())) }
    @available(*, unavailable) required dynamic init?(coder aDecoder: NSCoder) { fatalError("Use the programmatic TabView root") }
}
