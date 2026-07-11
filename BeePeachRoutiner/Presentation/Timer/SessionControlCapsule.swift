import UIKit
import SnapKit

// MARK: - SessionControlCapsule

/// 세션 제어 버튼을 담는 흰색 pill 캡슐.
///
/// 구성: [정사각 stop 버튼][원형 play/pause 버튼] 의 horizontal stack.
/// 모드(Dial/Digital)는 표시 방식일 뿐이므로 이 캡슐은 모든 모드에서 공유된다.
///
/// 외부 노출은 기존 커스텀 뷰 관례대로 클로저 콜백 — 뷰 자체는 Rx 를 모른다.
final class SessionControlCapsule: UIView {

    // MARK: - Public API

    /// play/pause 버튼 tap 시 호출된다. 분기(start/pause/resume)는 호출측 책임.
    var onPlayPauseTapped: (() -> Void)?

    /// stop 버튼 tap 시 호출된다.
    var onStopTapped: (() -> Void)?

    // MARK: - Configuration

    /// 버튼 한 변(pt). 정사각 stop / 원형 play-pause 공통.
    private let buttonSide: CGFloat = 48
    /// 캡슐 내부 여백(pt). 버튼과 pill 테두리 사이 간격.
    private let contentInset: CGFloat = 8

    // MARK: - UI

    private let stopButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "stop.fill"), for: .normal)
        button.tintColor = .systemRed
        button.backgroundColor = .systemGray6
        button.layer.cornerRadius = 12
        return button
    }()

    private let playPauseButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "play.fill"), for: .normal)
        button.tintColor = .label
        button.backgroundColor = .systemGray6
        button.layer.cornerRadius = 24
        return button
    }()

    // MARK: - Initialization

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        // pill: 높이의 절반을 corner 로 — 어떤 높이로 계산되든 캡슐 형태 유지.
        layer.cornerRadius = bounds.height / 2
    }

    // MARK: - Setup

    private func setupUI() {
        backgroundColor = .white
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.1
        layer.shadowRadius = 8
        layer.shadowOffset = CGSize(width: 0, height: 2)

        let stackView = UIStackView(arrangedSubviews: [stopButton, playPauseButton])
        stackView.axis = .horizontal
        stackView.spacing = 8
        addSubview(stackView)

        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(contentInset)
        }
        stopButton.snp.makeConstraints { make in
            make.width.height.equalTo(buttonSide)
        }
        playPauseButton.snp.makeConstraints { make in
            make.width.height.equalTo(buttonSide)
        }

        stopButton.addTarget(self, action: #selector(stopTapped), for: .touchUpInside)
        playPauseButton.addTarget(self, action: #selector(playPauseTapped), for: .touchUpInside)
    }

    // MARK: - Actions

    @objc private func stopTapped() {
        onStopTapped?()
    }

    @objc private func playPauseTapped() {
        onPlayPauseTapped?()
    }
}
