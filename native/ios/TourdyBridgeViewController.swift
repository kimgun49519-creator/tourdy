import Capacitor

@objc(TourdyBridgeViewController)
public class TourdyBridgeViewController: CAPBridgeViewController {
    weak var navigationModel: TourdyNavigationModel?
    public override func capacitorDidLoad() { bridge?.registerPluginInstance(TourdyRecordsPlugin()) }
    func updateNavigation(tab: String, travelEnabled: Bool, locked: Bool, modal: Bool, dark: Bool, systemTheme: Bool, revision: Int, request: Int) {
        navigationModel?.receive(tab: tab, travelEnabled: travelEnabled, locked: locked, modal: modal, dark: dark, systemTheme: systemTheme, revision: revision, request: request)
    }
}
