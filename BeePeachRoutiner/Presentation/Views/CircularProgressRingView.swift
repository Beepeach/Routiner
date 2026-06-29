import UIKit

// MARK: - CircularProgressRingView

/// 두꺼운 호 + 둥근 line cap 으로 손잡이 모양을 자연스럽게 표현하는 회전 다이얼.
///
/// 인터랙션:
/// - 채워진 호(0 ~ currentRatio) 위 어디든 잡고 회전할 수 있다. iOS 시계 앱 수면 화면과 동일.
/// - `currentRatio == 0` 일 때만 12시 손잡이 위치 근처에 한해 hit 가 허용된다 (빈 트랙 어디든 잡혀 점프하는 사고 방지).
/// - 매 snap step 변경 시 `UISelectionFeedbackGenerator` 햅틱이 트리거된다.
///
/// 표시:
/// - 12시 방향에서 시계 방향으로 차오른다 (`startAngle = -π/2`).
/// - 호 두께는 `lineWidth`. lineCap=.round 라서 호 양 끝이 둥글어 손잡이로 보인다.
final class CircularProgressRingView: UIView {

    // MARK: - Public API

    /// 사용자가 회전시켰을 때 호출된다. 시스템(timer 등) 갱신은 트리거하지 않는다.
    /// 전달되는 ratio 는 `snapStep` 적용된 값.
    var onRatioChanged: ((CGFloat) -> Void)?

    /// false 면 Pan 입력을 무시한다. 세션이 진행 중일 때 외부에서 잠근다.
    var isDialEnabled: Bool = true

    /// Pan 입력의 스냅 단위 (0~1 범위). 예: `1.0/60` 이면 1분 단위 (60분 다이얼 기준).
    /// nil 이면 스냅 없이 raw 값을 사용한다. `setRatio(_:)` 외부 주입에는 적용되지 않는다.
    var snapStep: CGFloat?

    /// 외부에서 ratio (0~1) 를 강제 설정한다. 시스템이 timer 로 갱신할 때 사용.
    /// `onRatioChanged` 는 발화하지 않으며, snap/햅틱도 적용되지 않는다.
    /// - Parameter animationDuration: 0 보다 크면 그 시간 동안 보간 애니메이션을 적용.
    ///   timer tick 처럼 큰 간격 사이를 부드럽게 채울 때 사용한다.
    func setRatio(_ ratio: CGFloat, animationDuration: CFTimeInterval = 0) {
        currentRatio = clamped(ratio)
        applyRatio(currentRatio, duration: animationDuration)
    }

    // MARK: - Configuration

    /// 호 두께(pt). 시계 앱 수면 화면 정도의 굵기.
    private let lineWidth: CGFloat = 32
    /// hit 영역 확장 여유(pt). band 안팎과 호 끝(손잡이) 부근 모두에 적용.
    private let knobHitSlop: CGFloat = 12
    /// ratio=0(빈 다이얼)일 때 12시 노브를 잡을 수 있는 각도 윈도우(±도).
    /// 거리(캐치 반경) 대신 각도로 판정해 화면 크기와 무관하게 일정한 grab 폭을 준다.
    /// 90° 미만 유지 — 그 이상이면 빈 트랙 임의 지점(예: 3시=90°)이 잡혀 점프 위험.
    private let emptyDialKnobAngleTolerance: CGFloat = 45
    /// 호 안쪽에 그리는 분 단위 tick 갯수. snapStep 와 시각 정합성을 맞추기 위해 60.
    private let tickCount: Int = 60
    /// tick 길이(pt).
    private let tickLength: CGFloat = 6
    /// tick 두께(pt).
    private let tickWidth: CGFloat = 1.5
    /// 호 안쪽과 tick 사이 간격(pt).
    private let tickInset: CGFloat = 6
    /// knob(손잡이) 직경(pt). 호 두께보다 살짝 작게 잡아 호 끝에 박힌 형태.
    private let knobDiameter: CGFloat = 28
    /// knob 보더 두께.
    private let knobBorderWidth: CGFloat = 2

    // MARK: - State

    private var currentRatio: CGFloat = 0
    /// Pan 진행 중 직전 손가락 각도. 누적 델타 계산에 사용.
    private var panLastAngle: CGFloat = 0

    // MARK: - Layers

    private let trackLayer = CAShapeLayer()
    private let progressLayer = CAShapeLayer()
    private let tickLayer = CAShapeLayer()
    private let knobLayer = CAShapeLayer()

    // MARK: - Haptics

    /// snap step 변경마다 selectionChanged() 를 호출해 시계 앱 다이얼 느낌의 햅틱을 낸다.
    private let selectionFeedback = UISelectionFeedbackGenerator()

    // MARK: - Initialization

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayers()
        setupGesture()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        updatePaths()
        applyRatio(currentRatio)
    }

    // MARK: - Setup

    private func setupLayers() {
        backgroundColor = .clear

        configureArc(trackLayer, strokeColor: UIColor.systemGray5.cgColor)
        trackLayer.strokeEnd = 1
        layer.addSublayer(trackLayer)

        configureArc(progressLayer, strokeColor: UIColor.systemBlue.cgColor)
        progressLayer.strokeEnd = 0
        layer.addSublayer(progressLayer)

        tickLayer.strokeColor = UIColor.systemGray3.cgColor
        tickLayer.fillColor = UIColor.clear.cgColor
        tickLayer.lineWidth = tickWidth
        tickLayer.lineCap = .round
        layer.addSublayer(tickLayer)

        // knob: path 와 bounds 는 한 번만 고정. 매번 position 만 갱신해 progressLayer.strokeEnd
        // 와 같은 단순 값 보간으로 동기를 맞춘다 (path 보간은 strokeEnd 와 타이밍이 미세하게 어긋남).
        let knobBounds = CGRect(x: 0, y: 0, width: knobDiameter, height: knobDiameter)
        knobLayer.bounds = knobBounds
        let knobPath = UIBezierPath(ovalIn: knobBounds).cgPath
        knobLayer.path = knobPath
        knobLayer.fillColor = UIColor.white.cgColor
        knobLayer.strokeColor = UIColor.systemBlue.cgColor
        knobLayer.lineWidth = knobBorderWidth
        // shadowPath 명시: shadow 가 path 기반 캐싱돼 매 frame 오프스크린 렌더링 비용 0.
        knobLayer.shadowColor = UIColor.black.cgColor
        knobLayer.shadowOffset = CGSize(width: 0, height: 1)
        knobLayer.shadowRadius = 2
        knobLayer.shadowOpacity = 0.15
        knobLayer.shadowPath = knobPath
        layer.addSublayer(knobLayer)
    }

    private func configureArc(_ shapeLayer: CAShapeLayer, strokeColor: CGColor) {
        shapeLayer.strokeColor = strokeColor
        shapeLayer.fillColor = UIColor.clear.cgColor
        shapeLayer.lineWidth = lineWidth
        shapeLayer.lineCap = .round
    }

    private func setupGesture() {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        addGestureRecognizer(pan)
    }

    // MARK: - Pan Handling

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard isDialEnabled else {
            cancel(gesture)
            return
        }

        let touchPoint = gesture.location(in: self)

        switch gesture.state {
        case .began:
            guard isWithinHitZone(touchPoint) else {
                cancel(gesture)
                return
            }
            panLastAngle = absoluteAngle(of: touchPoint)
            selectionFeedback.prepare()
        case .changed:
            let now = absoluteAngle(of: touchPoint)
            let delta = wrappedDelta(from: panLastAngle, to: now)
            panLastAngle = now
            applyDeltaAngle(delta)
        default:
            break
        }
    }

    /// 손가락 이동 각도(`-π~π`)를 ratio(0~1) 로 환산해 누적·clamp·snap 한 뒤 적용한다.
    /// `internal` 가시성: PanGesture 시뮬레이션이 어려운 단위 테스트가 직접 호출해 검증한다.
    func applyDeltaAngle(_ deltaAngle: CGFloat) {
        let ratioDelta = deltaAngle / (2 * .pi)
        let candidate = clamped(currentRatio + ratioDelta)
        let snapped = snap(candidate)
        guard snapped != currentRatio else { return }
        currentRatio = snapped
        // 1분 step 점프 사이를 짧은 ease-out 으로 보간해 끊김(jitter) 해소.
        applyRatio(snapped, duration: 0.08)
        selectionFeedback.selectionChanged()
        selectionFeedback.prepare() // 다음 step 발사 latency 감소
        onRatioChanged?(snapped)
    }

    /// PanGesture 를 즉시 cancel.
    private func cancel(_ gesture: UIPanGestureRecognizer) {
        gesture.isEnabled = false
        gesture.isEnabled = true
    }

    // MARK: - Hit Test

    /// 사용자가 채워진 호 위 어디든 잡거나, ratio=0 일 땐 12시 손잡이 부근을 잡았는지 검사.
    /// `internal` 가시성: 단위 테스트가 직접 호출해 검증.
    func isWithinHitZone(_ point: CGPoint) -> Bool {
        let center = ringCenter
        let distance = hypot(point.x - center.x, point.y - center.y)
        let innerEdge = ringRadius - lineWidth / 2 - knobHitSlop
        let outerEdge = ringRadius + lineWidth / 2 + knobHitSlop
        guard distance >= innerEdge && distance <= outerEdge else { return false }

        // 빈 다이얼: 12시 기준 ±emptyDialKnobAngleTolerance 도 안의 호 조각만 hit 허용.
        if currentRatio <= 0 {
            let touchRatio = normalizedRatio(from: absoluteAngle(of: point))
            let ratioFromTop = min(touchRatio, 1 - touchRatio) // 12시까지 양방향 최단(ratio)
            return ratioFromTop <= emptyDialKnobAngleTolerance / 360
        }

        // 채워진 호 위인지 확인: 손가락 위치의 ratio 가 [0, currentRatio + tolerance] 안인가
        let touchRatio = normalizedRatio(from: absoluteAngle(of: point))
        let arcLengthSlop = knobHitSlop // 손잡이 끝을 살짝 넘어가도 잡히도록 호 길이만큼 여유
        let tolerance = arcLengthSlop / max(2 * .pi * ringRadius, 1)
        return touchRatio <= currentRatio + tolerance
    }

    // MARK: - Geometry

    private var ringRadius: CGFloat {
        (min(bounds.width, bounds.height) / 2) - (lineWidth / 2)
    }

    private var ringCenter: CGPoint {
        CGPoint(x: bounds.midX, y: bounds.midY)
    }

    /// 12시 정렬된 절대 각도(시계방향 양수). normalize 는 호출자가 필요한 곳에서.
    private func absoluteAngle(of point: CGPoint) -> CGFloat {
        let center = ringCenter
        return atan2(point.y - center.y, point.x - center.x) + .pi / 2
    }

    /// 절대 각도를 0~1 ratio 로 normalize.
    private func normalizedRatio(from angle: CGFloat) -> CGFloat {
        var normalized = angle.truncatingRemainder(dividingBy: 2 * .pi)
        if normalized < 0 { normalized += 2 * .pi }
        return CGFloat(normalized / (2 * .pi))
    }

    /// 두 각도 사이의 짧은 쪽 차이를 반환. wrap-around 차단.
    private func wrappedDelta(from previous: CGFloat, to current: CGFloat) -> CGFloat {
        var delta = current - previous
        if delta > .pi { delta -= 2 * .pi }
        if delta < -.pi { delta += 2 * .pi }
        return delta
    }

    /// `snapStep` 단위로 라운드한 ratio.
    private func snap(_ ratio: CGFloat) -> CGFloat {
        guard let step = snapStep, step > 0 else { return ratio }
        let snapped = (ratio / step).rounded() * step
        return clamped(snapped)
    }

    /// 주어진 ratio 위치의 ring 위 점.
    private func pointOnRing(for ratio: CGFloat) -> CGPoint {
        let clamped = self.clamped(ratio)
        let angle = -CGFloat.pi / 2 + 2 * .pi * clamped
        return CGPoint(
            x: ringCenter.x + ringRadius * cos(angle),
            y: ringCenter.y + ringRadius * sin(angle)
        )
    }

    // MARK: - Helpers

    private func clamped(_ value: CGFloat) -> CGFloat {
        max(0, min(value, 1))
    }

    private func updatePaths() {
        guard ringRadius > 0 else { return }
        let arcPath = UIBezierPath(
            arcCenter: ringCenter,
            radius: ringRadius,
            startAngle: -.pi / 2,
            endAngle: 3 * .pi / 2,
            clockwise: true
        ).cgPath
        trackLayer.frame = bounds
        progressLayer.frame = bounds
        tickLayer.frame = bounds
        // knobLayer.frame 은 건드리지 않는다. bounds 는 setupLayers 에서 knobBounds 로 고정,
        // 위치는 applyRatio 의 position 갱신으로만 관리한다.
        trackLayer.path = arcPath
        progressLayer.path = arcPath
        tickLayer.path = makeTickPath().cgPath
    }

    /// 호 안쪽에 60 개 (또는 `tickCount`) 의 짧은 line 을 한 path 로 그린다.
    /// 12 시(top) 에서 시작해 시계 방향으로 균일 분포.
    private func makeTickPath() -> UIBezierPath {
        let path = UIBezierPath()
        let outerRadius = ringRadius - lineWidth / 2 - tickInset
        let innerRadius = outerRadius - tickLength
        guard innerRadius > 0 else { return path }

        for index in 0..<tickCount {
            let angle = -CGFloat.pi / 2 + 2 * .pi * CGFloat(index) / CGFloat(tickCount)
            let outer = CGPoint(
                x: ringCenter.x + outerRadius * cos(angle),
                y: ringCenter.y + outerRadius * sin(angle)
            )
            let inner = CGPoint(
                x: ringCenter.x + innerRadius * cos(angle),
                y: ringCenter.y + innerRadius * sin(angle)
            )
            path.move(to: outer)
            path.addLine(to: inner)
        }
        return path
    }

    /// strokeEnd 와 knob 위치를 ratio 에 맞춰 갱신.
    /// - Parameter duration: 0 이면 implicit 애니메이션 차단 (즉시 적용),
    ///   양수면 그 시간 동안 ease-out 보간.
    ///
    /// knob 은 path 를 매번 새로 만들지 않고 `position` 만 이동시킨다.
    /// progressLayer.strokeEnd(단순 값 보간) 와 같은 종류의 보간이라 둘이 정확히 동기된다.
    private func applyRatio(_ ratio: CGFloat, duration: CFTimeInterval = 0) {
        CATransaction.begin()
        if duration > 0 {
            CATransaction.setAnimationDuration(duration)
            CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeOut))
        } else {
            CATransaction.setDisableActions(true)
        }
        progressLayer.strokeEnd = ratio
        knobLayer.position = pointOnRing(for: ratio)
        CATransaction.commit()
    }
}
