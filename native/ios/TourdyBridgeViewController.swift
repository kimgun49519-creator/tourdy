import Capacitor

@objc(TourdyBridgeViewController)
public class TourdyBridgeViewController: CAPBridgeViewController {
    public override func capacitorDidLoad() {
        bridge?.registerPluginInstance(TourdyRecordsPlugin())
    }
}
