import UIKit
import SnapKit

// MARK: - WorkLogModalViewController

/// 세션 종료 시 작업 기록(workNote)을 입력받는 half-sheet 모달.
///
/// 어떤 경로로 닫히든(저장/닫기/스와이프) `onComplete` 를 정확히 1회 호출한다 —
/// 세션 기록 자체는 유실되면 안 되기 때문. 저장: 입력 텍스트, 그 외: nil.
/// 도메인 로직이 없어(텍스트 수집 후 반환뿐) 별도 ViewModel 은 두지 않는다.
final class WorkLogModalViewController: UIViewController {

    // MARK: - Public API

    /// 모달이 닫힌 뒤 1회 호출된다. 저장하기: trimmed 텍스트(빈 입력은 nil), 닫기/스와이프: nil.
    var onComplete: ((String?) -> Void)?

    // MARK: - State

    /// dismiss 전에 확정되는 결과. 저장하기에서만 텍스트가 담긴다.
    private var result: String?

    // MARK: - UI

    /// 테스트에서 입력/탭을 시뮬레이션할 수 있도록 UI 요소는 internal 로 둔다.
    let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "작업 기록"
        label.font = .systemFont(ofSize: 20, weight: .bold)
        label.textAlignment = .center
        return label
    }()

    let promptLabel: UILabel = {
        let label = UILabel()
        label.text = "어떤 작업을 했나요?"
        label.font = .systemFont(ofSize: 15)
        label.textColor = .secondaryLabel
        return label
    }()

    let textView: UITextView = {
        let textView = UITextView()
        textView.font = .systemFont(ofSize: 16)
        textView.backgroundColor = .secondarySystemBackground
        textView.layer.cornerRadius = 12
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 8, bottom: 12, right: 8)
        return textView
    }()

    let placeholderLabel: UILabel = {
        let label = UILabel()
        label.text = "작업 내용을 입력하세요..."
        label.font = .systemFont(ofSize: 16)
        label.textColor = .tertiaryLabel
        return label
    }()

    let saveButton: UIButton = {
        var configuration = UIButton.Configuration.filled()
        configuration.title = "저장하기"
        return UIButton(configuration: configuration)
    }()

    let closeButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.title = "닫기"
        configuration.baseForegroundColor = .secondaryLabel
        return UIButton(configuration: configuration)
    }()

    let footnoteLabel: UILabel = {
        let label = UILabel()
        label.text = "* 1분 미만 진행된 세션은 기록되지 않습니다."
        label.font = .preferredFont(forTextStyle: .footnote)
        label.textColor = .secondaryLabel
        return label
    }()

    // MARK: - Initialization

    init() {
        super.init(nibName: nil, bundle: nil)
        // .automatic 은 presentation 시작 전까지 sheetPresentationController 가 nil 일 수 있어
        // pageSheet 로 고정하고 모달 스스로 detent 를 구성한다.
        modalPresentationStyle = .pageSheet
        sheetPresentationController?.detents = [.medium()]
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        // 버튼 dismiss/스와이프 dismiss 가 모두 이 지점으로 수렴한다.
        // nil 재할당으로 1회 호출을 보장 — 세션 종료(end)가 중복 발사되면 안 된다.
        onComplete?(result)
        onComplete = nil
    }

    // MARK: - Setup

    private func setupUI() {
        view.backgroundColor = .systemBackground
        textView.delegate = self

        view.addSubview(titleLabel)
        view.addSubview(promptLabel)
        view.addSubview(textView)
        textView.addSubview(placeholderLabel)
        view.addSubview(saveButton)
        view.addSubview(closeButton)
        view.addSubview(footnoteLabel)

        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(24)
            make.centerX.equalToSuperview()
        }
        promptLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(16)
            make.leading.equalToSuperview().offset(20)
        }
        textView.snp.makeConstraints { make in
            make.top.equalTo(promptLabel.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview().inset(20)
            make.height.equalTo(120)
        }
        placeholderLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(12)
            make.leading.equalToSuperview().offset(12)
        }
        saveButton.snp.makeConstraints { make in
            make.top.equalTo(textView.snp.bottom).offset(20)
            make.leading.trailing.equalToSuperview().inset(20)
            make.height.equalTo(50)
        }
        closeButton.snp.makeConstraints { make in
            make.top.equalTo(saveButton.snp.bottom).offset(4)
            make.centerX.equalToSuperview()
            make.height.equalTo(44)
        }
        footnoteLabel.snp.makeConstraints { make in
            make.top.equalTo(closeButton.snp.bottom).offset(8)
            make.leading.equalToSuperview().offset(20)
        }

        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
    }

    // MARK: - Actions

    @objc private func saveTapped() {
        let trimmed = textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        result = trimmed.isEmpty ? nil : trimmed
        dismiss(animated: true)
    }

    @objc private func closeTapped() {
        result = nil
        dismiss(animated: true)
    }
}

// MARK: - UITextViewDelegate

extension WorkLogModalViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        placeholderLabel.isHidden = !textView.text.isEmpty
    }
}
