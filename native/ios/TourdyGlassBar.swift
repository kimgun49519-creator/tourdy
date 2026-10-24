import SwiftUI

final class TourdyNavigationModel: ObservableObject {
    @Published var selected = "home"
    @Published var travelEnabled = false
    @Published var locked = false
    var select: (String) -> Void = { _ in }
}

struct TourdyGlassBar: View {
    @ObservedObject var model: TourdyNavigationModel
    private let tabs = [("home", "홈", "house"), ("todo", "할 일", "checkmark.square"),
                        ("stats", "대시보드", ""), ("travel", "여행", "airplane"), ("set", "설정", "gearshape")]
    var body: some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular.interactive(), in: .capsule)
        } else {
            content.background(.ultraThinMaterial, in: Capsule())
        }
    }
    private var content: some View {
        HStack(spacing: 2) {
            ForEach(tabs.filter { $0.0 != "travel" || model.travelEnabled }, id: \.0) { tab in
                Button { model.select(tab.0) } label: {
                    VStack(spacing: 5) {
                        Group {
                            if tab.0 == "stats" { DashboardMark() }
                            else { Image(systemName: tab.2).font(.system(size: 23, weight: .medium)) }
                        }.frame(width: 27, height: 27)
                        Text(tab.1).font(.system(size: 11, weight: .semibold)).lineLimit(1)
                    }
                    .foregroundStyle(model.selected == tab.0 ? Color.primary : Color.secondary)
                    .frame(maxWidth: .infinity).frame(height: 66)
                    .background {
                        if model.selected == tab.0 {
                            Capsule().fill(Color.primary.opacity(0.09))
                                .overlay(Capsule().strokeBorder(Color.white.opacity(0.25), lineWidth: 0.6))
                        }
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain).disabled(model.locked)
                .accessibilityLabel(tab.1)
                .accessibilityAddTraits(model.selected == tab.0 ? .isSelected : [])
                .accessibilityIdentifier("tourdy.tab." + tab.0)
            }
        }.padding(6)
    }
}

// A small dashboard of three independent panels, rather than the reference's chart icon.
private struct DashboardMark: View {
    var body: some View {
        HStack(spacing: 3) {
            RoundedRectangle(cornerRadius: 2).stroke(lineWidth: 1.8).frame(width: 9, height: 23)
            VStack(spacing: 3) {
                RoundedRectangle(cornerRadius: 2).stroke(lineWidth: 1.8).frame(height: 8)
                RoundedRectangle(cornerRadius: 2).stroke(lineWidth: 1.8).frame(height: 12)
            }.frame(width: 11)
        }.frame(width: 24, height: 25).accessibilityHidden(true)
    }
}
