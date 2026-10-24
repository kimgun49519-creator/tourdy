import Foundation
import Capacitor

@objc(TourdyRecordsPlugin)
public class TourdyRecordsPlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "TourdyRecordsPlugin"
    public let jsName = "TourdyRecords"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name:"readRecords",returnType:CAPPluginReturnPromise),
        CAPPluginMethod(name:"commit",returnType:CAPPluginReturnPromise),
        CAPPluginMethod(name:"navigationState",returnType:CAPPluginReturnPromise)
    ]
    private static let queue = DispatchQueue(label:"app.tourdy.atomic-records")
    @objc func navigationState(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            guard let controller = self.bridge?.viewController as? TourdyBridgeViewController else {
                call.reject("Navigation is unavailable"); return
            }
            controller.updateNavigation(tab:call.getString("tab") ?? "home", travelEnabled:call.getBool("travelEnabled") ?? false,
                locked:call.getBool("locked") ?? false, modal:call.getBool("modal") ?? false,
                dark:call.getBool("dark") ?? false, revision:call.getInt("revision") ?? 0)
            call.resolve()
        }
    }
    private func fileURL() throws -> URL {
        let directory=FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("TourdyShared",isDirectory:true)
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
        return directory.appendingPathComponent("records-v1.json")
    }
    @objc func readRecords(_ call: CAPPluginCall) {
        Self.queue.async {
            do {
                let url=try self.fileURL()
                if !FileManager.default.fileExists(atPath:url.path) {call.resolve(["data":NSNull()]);return}
                let data=try Data(contentsOf:url)
                guard let raw=String(data:data,encoding:.utf8) else {throw CocoaError(.fileReadCorruptFile)}
                call.resolve(["data":raw])
            } catch {call.reject("기존 기록을 읽지 못했습니다. 파일을 변경하지 않았습니다.","READ_FAILED",error)}
        }
    }
    @objc func commit(_ call: CAPPluginCall) {
        guard let raw=call.getString("data"),let data=raw.data(using:.utf8) else {call.reject("Invalid record data","INVALID_DATA");return}
        let expected=call.getString("expected")
        Self.queue.async {
            do {
                guard let envelope=try JSONSerialization.jsonObject(with:data) as? [String:Any],
                      envelope["format"] as? Int == 1,
                      let records=envelope["records"] as? [String:String],
                      records.keys.allSatisfy({$0.range(of:"^studyplanner\\.v[12](\\.(lastGood|damaged))?$",options:.regularExpression) != nil}) else {throw CocoaError(.fileWriteInapplicableStringEncoding)}
                let url=try self.fileURL()
                let current: String?
                if FileManager.default.fileExists(atPath:url.path) {current=try String(contentsOf:url,encoding:.utf8)}else{current=nil}
                guard current==expected else {call.reject("다른 저장 작업에서 기록이 바뀌었습니다.","CONFLICT");return}
                // Foundation writes a sibling temporary file and atomically replaces
                // the destination. Never delete the valid destination before writing.
                if current != raw {try data.write(to:url,options:.atomic)}
                call.resolve()
            } catch {call.reject("기기에 저장하지 못했습니다. 기존 파일은 유지됩니다.","WRITE_FAILED",error)}
        }
    }
}
