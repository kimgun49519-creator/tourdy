import SwiftUI

struct TourdyIntro: View {
    let finish: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var opened = false
    @State private var flying = false
    @State private var progress: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            let canvas = geometry.size
            let origin = CGPoint(x: canvas.width / 2, y: canvas.height * 0.43)
            ZStack {
                Color(uiColor: .systemBackground).ignoresSafeArea()
                Circle().fill(Color.blue.opacity(0.07)).frame(width: 270, height: 270)
                    .blur(radius: 35).position(origin)
                if !reduceMotion {
                    FlightTrail().trim(from: 0, to: progress)
                        .stroke(Color.blue.opacity(0.3), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [4, 6]))
                }
                ZStack {
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 100, weight: .regular)).foregroundStyle(Color.blue)
                        .rotation3DEffect(.degrees(opened ? -75 : 0), axis: (x: 0, y: 1, z: 0))
                        .opacity(opened ? 0 : 1)
                    OpenBook().fill(Color.blue.opacity(0.09))
                        .overlay(OpenBook().stroke(Color.blue, style: StrokeStyle(lineWidth: 2.5, lineJoin: .round)))
                        .frame(width: 152, height: 100).opacity(opened ? 1 : 0)
                        .scaleEffect(x: opened ? 1 : 0.2, y: 1)
                }.position(origin)
                if !reduceMotion {
                    Image(systemName: "airplane").font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(Color.blue).opacity(flying ? 1 : 0)
                        .modifier(FlightMotion(progress: progress, canvas: canvas))
                        .position(origin)
                }
                VStack(spacing: 10) {
                    Text("TOURDY").font(.system(size: 30, weight: .bold, design: .rounded)).tracking(5)
                    Text("공부에서 시작되는 여행").font(.system(size: 14, weight: .medium)).foregroundStyle(.secondary)
                }.opacity(opened || reduceMotion ? 1 : 0).position(x: canvas.width / 2, y: canvas.height * 0.64)
                VStack {
                    Spacer()
                    Button("탭해서 시작", action: finish).font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary).frame(minWidth: 120, minHeight: 44).padding(.bottom, 20)
                }
            }.contentShape(Rectangle()).onTapGesture(perform: finish)
        }
        .accessibilityIdentifier("tourdy.intro")
        .task {
            do {
                if reduceMotion { try await Task.sleep(nanoseconds: 700_000_000); finish(); return }
                try await Task.sleep(nanoseconds: 180_000_000)
                withAnimation(.easeInOut(duration: 0.42)) { opened = true }
                try await Task.sleep(nanoseconds: 420_000_000)
                flying = true
                withAnimation(.linear(duration: 1.25)) { progress = 1 }
                try await Task.sleep(nanoseconds: 1_450_000_000)
                finish()
            } catch { return }
        }
    }
}

private struct OpenBook: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let x = rect.midX, y = rect.maxY - 7
        path.move(to: CGPoint(x: x, y: 12))
        path.addQuadCurve(to: CGPoint(x: 4, y: 5), control: CGPoint(x: x * 0.5, y: -3))
        path.addLine(to: CGPoint(x: 4, y: rect.maxY - 16))
        path.addQuadCurve(to: CGPoint(x: x, y: y), control: CGPoint(x: x * 0.55, y: rect.maxY - 24))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - 4, y: rect.maxY - 16), control: CGPoint(x: x * 1.45, y: rect.maxY - 24))
        path.addLine(to: CGPoint(x: rect.maxX - 4, y: 5))
        path.addQuadCurve(to: CGPoint(x: x, y: 12), control: CGPoint(x: x * 1.5, y: -3))
        path.addLine(to: CGPoint(x: x, y: y))
        return path
    }
}

private struct FlightTrail: Shape {
    func path(in rect: CGRect) -> Path {
        let origin = CGPoint(x: rect.midX, y: rect.height * 0.43)
        var path = Path(); path.move(to: origin)
        path.addCurve(to: CGPoint(x: origin.x + rect.width * 0.95, y: origin.y - rect.height * 0.32),
            control1: CGPoint(x: origin.x + rect.width * 0.12, y: origin.y - rect.height * 0.15),
            control2: CGPoint(x: origin.x + rect.width * 0.5, y: origin.y - rect.height * 0.4))
        return path
    }
}

private struct FlightMotion: GeometryEffect {
    var progress: CGFloat
    let canvas: CGSize
    var animatableData: CGFloat { get { progress } set { progress = newValue } }
    func effectValue(size: CGSize) -> ProjectionTransform {
        let t = progress, u = 1 - t
        let x = canvas.width * (3 * u * u * t * 0.12 + 3 * u * t * t * 0.5 + t * t * t * 0.95)
        let y = -canvas.height * (3 * u * u * t * 0.15 + 3 * u * t * t * 0.4 + t * t * t * 0.32)
        let dx = canvas.width * (3 * u * u * 0.12 + 6 * u * t * 0.38 + 3 * t * t * 0.45)
        let dy = -canvas.height * (3 * u * u * 0.15 + 6 * u * t * 0.25 - 3 * t * t * 0.08)
        let transform = CGAffineTransform(translationX: x + size.width / 2, y: y + size.height / 2)
            .rotated(by: atan2(dy, dx)).translatedBy(x: -size.width / 2, y: -size.height / 2)
        return ProjectionTransform(transform)
    }
}
