import Capacitor
import SwiftUI

@objc(TourdyBridgeViewController)
public class TourdyBridgeViewController: CAPBridgeViewController {
    private let navigationModel = TourdyNavigationModel()
    private var glassBar: UIHostingController<TourdyGlassBar>?
    private var revision = -1
    private var modalOpen = false
    private var keyboardOpen = false

    public override func capacitorDidLoad() {
        bridge?.registerPluginInstance(TourdyRecordsPlugin())
        navigationModel.select = { [weak self] tab in
            guard let self, !self.navigationModel.locked else { return }
            let allowed = ["home", "todo", "stats", "travel", "set"]
            guard allowed.contains(tab) else { return }
            // The web app owns selection. Do not optimistically select a native tab.
            self.webView?.evaluateJavaScript("window.TourdySelectTab && window.TourdySelectTab('\(tab)')", completionHandler: nil)
        }
        let host = UIHostingController(rootView: TourdyGlassBar(model: navigationModel))
        host.view.backgroundColor = .clear
        host.view.translatesAutoresizingMaskIntoConstraints = false
        host.view.isHidden = true
        addChild(host); view.addSubview(host.view); host.didMove(toParent: self)
        NSLayoutConstraint.activate([
            host.view.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            host.view.widthAnchor.constraint(equalTo: view.widthAnchor, constant: -28).withPriority(999),
            host.view.widthAnchor.constraint(lessThanOrEqualToConstant: 540),
            host.view.heightAnchor.constraint(equalToConstant: 78),
            host.view.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8)
        ])
        glassBar = host
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardChanged(_:)), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
    }

    func updateNavigation(tab: String, travelEnabled: Bool, locked: Bool, modal: Bool, dark: Bool, revision: Int) {
        guard revision > self.revision else { return }
        self.revision = revision
        navigationModel.selected = tab
        navigationModel.travelEnabled = travelEnabled
        navigationModel.locked = locked
        modalOpen = modal
        glassBar?.overrideUserInterfaceStyle = dark ? .dark : .light
        glassBar?.view.isHidden = modalOpen || keyboardOpen
    }

    @objc private func keyboardChanged(_ notification: Notification) {
        if let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
            keyboardOpen = view.convert(frame, from: nil).intersection(view.bounds).height > 80
            glassBar?.view.isHidden = modalOpen || keyboardOpen || revision < 0
        }
    }
}

private extension NSLayoutConstraint {
    func withPriority(_ value: Float) -> NSLayoutConstraint { priority = UILayoutPriority(value); return self }
}
