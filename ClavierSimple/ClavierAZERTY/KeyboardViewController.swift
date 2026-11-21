import UIKit

class KeyView: UIView {
    let label = UILabel()
    var keyIdentifier: String = ""
    var onTrigger: ((KeyView) -> Void)?
    var defaultColor: UIColor = .white {
        didSet { backgroundColor = defaultColor }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.cornerRadius = 6
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 1)
        layer.shadowOpacity = 0.28
        layer.shadowRadius = 0.4
        isUserInteractionEnabled = true
        isAccessibilityElement = true
        accessibilityTraits = .keyboardKey

        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 21, weight: .regular)
        label.textColor = .label
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.75
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            label.topAnchor.constraint(equalTo: topAnchor),
            label.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tap)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        onTrigger?(self)
    }

    @objc private func handleTap() {
        onTrigger?(self)
    }

    override func accessibilityActivate() -> Bool {
        onTrigger?(self)
        return true
    }
}

class KeyboardViewController: UIInputViewController {

    private var isUppercase = true
    private var isNumbers = false
    private var lastPressTime: TimeInterval = 0
    private let debounceInterval: TimeInterval = 0.30
    private var mainStackView: UIStackView!
    private var suggestionViews: [KeyView] = []
    private let textChecker = UITextChecker()

    private var keyboardBackgroundColor: UIColor {
        UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1.0)
                : UIColor(red: 0.82, green: 0.83, blue: 0.85, alpha: 1.0)
        }
    }

    private var standardKeyColor: UIColor {
        UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.26, green: 0.26, blue: 0.28, alpha: 1.0)
                : UIColor.white
        }
    }

    private var modifierKeyColor: UIColor {
        UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.18, green: 0.18, blue: 0.20, alpha: 1.0)
                : UIColor(red: 0.67, green: 0.69, blue: 0.73, alpha: 1.0)
        }
    }

    private let azertyRows = [
        ["A", "Z", "E", "R", "T", "Y", "U", "I", "O", "P"],
        ["Q", "S", "D", "F", "G", "H", "J", "K", "L", "M"],
        ["SHIFT", "W", "X", "C", "V", "B", "N", "'", "DEL"],
        ["123", "SPACE", ".", "?", "!", "RETURN"]
    ]

    private let numberRows = [
        ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"],
        ["-", "/", ":", ";", "(", ")", "€", "&", "@", "\""],
        ["ABC", ".", ",", "?", "!", "'", "+", "=", "DEL"],
        ["ABC", "SPACE", "_", "-", "/", "RETURN"]
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        setupKeyboardInterface()
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        updatePredictions()
    }

    private func setupKeyboardInterface() {
        view.subviews.forEach { $0.removeFromSuperview() }
        suggestionViews.removeAll()
        view.backgroundColor = keyboardBackgroundColor

        let heightConstraint = view.heightAnchor.constraint(equalToConstant: 310)
        heightConstraint.priority = UILayoutPriority(999)
        heightConstraint.isActive = true

        mainStackView = UIStackView()
        mainStackView.axis = .vertical
        mainStackView.distribution = .fill
        mainStackView.spacing = 10
        mainStackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(mainStackView)

        NSLayoutConstraint.activate([
            mainStackView.topAnchor.constraint(equalTo: view.topAnchor, constant: 6),
            mainStackView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -8),
            mainStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            mainStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8)
        ])

        let predictionStack = UIStackView()
        predictionStack.axis = .horizontal
        predictionStack.distribution = .fillEqually
        predictionStack.spacing = 1
        predictionStack.heightAnchor.constraint(equalToConstant: 42).isActive = true

        for _ in 0..<3 {
            let kv = KeyView()
            kv.layer.cornerRadius = 0
            kv.layer.shadowOpacity = 0
            kv.defaultColor = .clear
            kv.label.font = UIFont.systemFont(ofSize: 18, weight: .regular)
            kv.onTrigger = { [weak self] view in self?.predictionPressed(view) }
            suggestionViews.append(kv)
            predictionStack.addArrangedSubview(kv)
        }
        mainStackView.addArrangedSubview(predictionStack)

        let keysContainer = UIStackView()
        keysContainer.axis = .vertical
        keysContainer.distribution = .fillEqually
        keysContainer.spacing = 10

        let currentRows = isNumbers ? numberRows : azertyRows
        for (index, row) in currentRows.enumerated() {
            let rowStack = UIStackView()
            rowStack.axis = .horizontal
            rowStack.distribution = .fillProportionally
            rowStack.spacing = 6

            if index == 1 {
                rowStack.isLayoutMarginsRelativeArrangement = true
                rowStack.layoutMargins = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
            }

            for key in row {
                rowStack.addArrangedSubview(createKeyView(title: key, isBottomRow: index == 3))
            }
            keysContainer.addArrangedSubview(rowStack)
        }

        mainStackView.addArrangedSubview(keysContainer)
        updatePredictions()
    }

    private func createKeyView(title: String, isBottomRow: Bool) -> KeyView {
        let kv = KeyView()
        kv.keyIdentifier = title

        switch title {
        case "SHIFT":
            kv.label.text = "⇧"
            kv.label.font = UIFont.systemFont(ofSize: 20, weight: .medium)
            kv.defaultColor = isUppercase ? standardKeyColor : modifierKeyColor
            kv.widthAnchor.constraint(greaterThanOrEqualToConstant: 78).isActive = true
        case "DEL":
            kv.label.text = "⌫"
            kv.label.font = UIFont.systemFont(ofSize: 20, weight: .regular)
            kv.defaultColor = modifierKeyColor
            kv.widthAnchor.constraint(greaterThanOrEqualToConstant: 78).isActive = true
        case "123", "ABC":
            kv.label.text = title
            kv.label.font = UIFont.systemFont(ofSize: 17, weight: .regular)
            kv.defaultColor = modifierKeyColor
            kv.widthAnchor.constraint(greaterThanOrEqualToConstant: 82).isActive = true
        case "SPACE":
            kv.label.text = "espace"
            kv.label.font = UIFont.systemFont(ofSize: 17, weight: .regular)
            kv.defaultColor = standardKeyColor
            kv.widthAnchor.constraint(greaterThanOrEqualToConstant: 210).isActive = true
        case "RETURN":
            kv.label.text = "retour"
            kv.label.font = UIFont.systemFont(ofSize: 17, weight: .regular)
            kv.defaultColor = modifierKeyColor
            kv.widthAnchor.constraint(greaterThanOrEqualToConstant: 105).isActive = true
        case ".", "?", "!":
            kv.label.text = title
            kv.label.font = UIFont.systemFont(ofSize: 23, weight: .medium)
            kv.defaultColor = standardKeyColor
            if isBottomRow {
                kv.widthAnchor.constraint(greaterThanOrEqualToConstant: 76).isActive = true
            }
        default:
            kv.label.text = isUppercase ? title.uppercased() : title.lowercased()
            kv.defaultColor = standardKeyColor
        }

        kv.accessibilityLabel = kv.label.text
        kv.onTrigger = { [weak self] view in self?.keyPressed(view) }
        return kv
    }

    private func currentWordPrefix() -> String {
        guard let before = textDocumentProxy.documentContextBeforeInput, !before.isEmpty else { return "" }
        let separators = CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters)
        if let range = before.rangeOfCharacter(from: separators, options: .backwards) {
            return String(before[range.upperBound...])
        }
        return before
    }

    private func updatePredictions() {
        let prefix = currentWordPrefix()
        var suggestions: [String] = []

        if !prefix.isEmpty {
            let range = NSRange(location: 0, length: (prefix as NSString).length)
            if let completions = textChecker.completions(forPartialWordRange: range, in: prefix, language: "fr_FR") {
                suggestions.append(contentsOf: completions)
            }
            if suggestions.count < 3, let guesses = textChecker.guesses(forWordRange: range, in: prefix, language: "fr_FR") {
                for guess in guesses where !suggestions.contains(guess) {
                    suggestions.append(guess)
                }
            }
        } else {
            suggestions = ["Bonjour", "Je", "Merci"]
        }

        for i in 0..<suggestionViews.count {
            if i < suggestions.count {
                let word = suggestions[i]
                let formatted = (prefix.first?.isUppercase == true) ? word.prefix(1).uppercased() + word.dropFirst() : word
                suggestionViews[i].label.text = formatted
                suggestionViews[i].accessibilityLabel = formatted
            } else {
                suggestionViews[i].label.text = ""
                suggestionViews[i].accessibilityLabel = ""
            }
        }
    }

    private func predictionPressed(_ sender: KeyView) {
        let now = Date().timeIntervalSince1970
        if now - lastPressTime < debounceInterval { return }
        lastPressTime = now

        let savedColor = sender.defaultColor
        sender.backgroundColor = modifierKeyColor.withAlphaComponent(0.4)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            sender.backgroundColor = savedColor
        }

        guard let chosenWord = sender.label.text, !chosenWord.isEmpty else { return }
        let prefix = currentWordPrefix()
        for _ in 0..<prefix.count {
            textDocumentProxy.deleteBackward()
        }
        textDocumentProxy.insertText(chosenWord + " ")
        isUppercase = false
        setupKeyboardInterface()
    }

    private func keyPressed(_ sender: KeyView) {
        let now = Date().timeIntervalSince1970
        if now - lastPressTime < debounceInterval { return }
        lastPressTime = now

        let savedColor = sender.defaultColor
        sender.backgroundColor = UIColor.systemGray3
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            sender.backgroundColor = savedColor
        }

        switch sender.keyIdentifier {
        case "SHIFT":
            isUppercase.toggle()
            setupKeyboardInterface()
        case "DEL":
            textDocumentProxy.deleteBackward()
            updatePredictions()
        case "123":
            isNumbers = true
            setupKeyboardInterface()
        case "ABC":
            isNumbers = false
            setupKeyboardInterface()
        case "SPACE":
            textDocumentProxy.insertText(" ")
            updatePredictions()
        case "RETURN":
            textDocumentProxy.insertText("\n")
            updatePredictions()
        default:
            let charToInsert = isUppercase ? sender.keyIdentifier.uppercased() : sender.keyIdentifier.lowercased()
            textDocumentProxy.insertText(charToInsert)
            if isUppercase && sender.keyIdentifier.rangeOfCharacter(from: .letters) != nil {
                isUppercase = false
                setupKeyboardInterface()
            } else {
                updatePredictions()
            }
        }
    }
}
