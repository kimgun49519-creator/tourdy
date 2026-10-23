import SwiftUI
import WebKit

@main
struct TourdyApp: App {
    var body: some Scene { WindowGroup { TourdyScreen() } }
}

struct NativeSwitch: Identifiable, Decodable {
    let id: String
    let title: String
    let on: Bool
    let x: Double
    let y: Double
    let width: Double
    let height: Double
}

@MainActor
final class TourdyModel: NSObject, ObservableObject, WKScriptMessageHandler, WKNavigationDelegate {
    @Published var switches: [NativeSwitch] = []
    @Published var tabs: [NativeSwitch] = []
    @Published var selectedTab = "home"
    @Published var error: String?
    let web: WKWebView

    override init() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        web = WKWebView(frame: .zero, configuration: config)
        super.init()
        config.userContentController.add(self, name: "tourdySwitches")
        config.userContentController.add(self, name: "tourdyTabs")
        web.navigationDelegate = self
        web.scrollView.contentInsetAdjustmentBehavior = .never
        guard let root = Bundle.main.url(forResource: "Web", withExtension: nil),
              let bridge = try? String(contentsOf: root.appendingPathComponent("native-bridge.js"), encoding: .utf8) else {
            error = "앱에 포함된 파일을 찾지 못했어요. Web 리소스를 확인해 주세요."
            return
        }
        config.userContentController.addUserScript(WKUserScript(source: bridge, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        web.loadFileURL(root.appendingPathComponent("index.html"), allowingReadAccessTo: root)
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.frameInfo.isMainFrame,
              let data = try? JSONSerialization.data(withJSONObject: message.body),
              let rows = try? JSONDecoder().decode([NativeSwitch].self, from: data) else { return }
        if message.name == "tourdySwitches" { switches = rows }
        if message.name == "tourdyTabs" {
            tabs = rows
            if let selected = rows.first(where: { $0.on }) { selectedTab = selected.id }
        }
    }

    func selectTab(_ id: String) {
        guard tabs.contains(where: { $0.id == id }) else { return }
        selectedTab = id
        guard let data = try? JSONSerialization.data(withJSONObject: [id]),
              let argument = String(data: data, encoding: .utf8) else { return }
        web.evaluateJavaScript("window.tourdyNativeSelectTab(...\(argument))") { [weak self] _, failure in
            if failure != nil { self?.error = "화면을 전환하지 못했어요. 다시 시도해 주세요." }
        }
    }

    func change(_ item: NativeSwitch, to value: Bool) {
        guard let data = try? JSONSerialization.data(withJSONObject: [item.id, value]),
              let argument = String(data: data, encoding: .utf8) else { return }
        web.evaluateJavaScript("window.tourdyNativeToggle(...\(argument))") { [weak self] _, failure in
            if failure != nil { self?.error = "설정을 변경하지 못했어요. 다시 시도해 주세요." }
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        // Only the bundled app may run in this view; no remote page receives the bridge.
        decisionHandler(navigationAction.request.url?.isFileURL == true ? .allow : .cancel)
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        self.error = "앱 화면을 불러오지 못했어요: \(error.localizedDescription)"
    }
}

struct AppWebView: UIViewRepresentable {
    let model: TourdyModel
    func makeUIView(context: Context) -> WKWebView { model.web }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

struct TourdyScreen: View {
    @StateObject private var model = TourdyModel()
    var body: some View {
        TabView(selection: Binding(get: { model.selectedTab }, set: { model.selectTab($0) })) {
            ForEach(model.tabs) { item in
                Group {
                    if item.id == model.selectedTab {
                        TourdyWebContent(model: model)
                    } else {
                        Color.clear
                    }
                }
                .tabItem { Label(item.title, systemImage: tabIcon(item.id)) }
                .tag(item.id)
            }
        }
        .tabViewStyle(.tabBarOnly)
        .overlay {
            if model.tabs.isEmpty { TourdyWebContent(model: model) }
        }
        .alert("확인해 주세요", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
            Button("확인") { model.error = nil }
        } message: { Text(model.error ?? "") }
    }

    private func tabIcon(_ id: String) -> String {
        switch id {
        case "home": return "timer"
        case "todo": return "checklist"
        case "stats": return "chart.bar.xaxis"
        case "travel": return "airplane"
        case "set": return "gearshape.fill"
        default: return "circle"
        }
    }
}

struct TourdyWebContent: View {
    @ObservedObject var model: TourdyModel
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                AppWebView(model: model)
                ForEach(model.switches) { item in
                    Toggle(item.title, isOn: Binding(get: { item.on }, set: { model.change(item, to: $0) }))
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .accessibilityLabel(item.title)
                        .frame(width: item.width, height: item.height)
                        .offset(x: item.x, y: item.y)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
            .clipped()
        }
    }
}
