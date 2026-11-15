import UIKit

class KeyboardViewController: UIInputViewController {

    private var isUppercase = true
    private var isNumbers = false
    private var lastPressTime: TimeInterval = 0
    private let debounceInterval: TimeInterval = 0.30
    private var mainStackView: UIStackView!
    private var suggestionButtons: [UIButton] = []
    private let textChecker = UITextChecker()

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

    private func attachSwitchEvents(to button: UIButton, action: Selector) {
        button.isUserInteractionEnabled = true
        button.addTarget(self, action: action, for: [.touchDown, .touchUpInside, .primaryActionTriggered])
        let tap = UITapGestureRecognizer(target: self, action: #selector(handlePointerTap(_:)))
        button.addGestureRecognizer(tap)
    }

    @objc private func handlePointerTap(_ gesture: UITapGestureRecognizer) {
        guard let button = gesture.view as? UIButton else { return }
        if suggestionButtons.contains(button) {
            predictionPressed(button)
        } else {
            keyPressed(button)
        }
    }

    private func setupKeyboardInterface() {
        view.subviews.forEach { $0.removeFromSuperview() }
        suggestionButtons.removeAll()
        view.backgroundColor = UIColor(white: 0.85, alpha: 1.0)

        mainStackView = UIStackView()
        mainStackView.axis = .vertical
        mainStackView.distribution = .fillEqually
        mainStackView.spacing = 8
        mainStackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(mainStackView)

        NSLayoutConstraint.activate([
            mainStackView.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            mainStackView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -8),
            mainStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            mainStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8)
        ])

        let predictionStack = UIStackView()
        predictionStack.axis = .horizontal
        predictionStack.distribution = .fillEqually
        predictionStack.spacing = 8

        for _ in 0..<3 {
            let btn = UIButton(type: .custom)
            btn.layer.cornerRadius = 8
            btn.backgroundColor = UIColor(white: 0.94, alpha: 1.0)
            btn.setTitleColor(.black, for: .normal)
            btn.titleLabel?.font = UIFont.systemFont(ofSize: 22, weight: .semibold)
            attachSwitchEvents(to: btn, action: #selector(predictionPressed(_:)))
            suggestionButtons.append(btn)
            predictionStack.addArrangedSubview(btn)
        }
        mainStackView.addArrangedSubview(predictionStack)

        let currentRows = isNumbers ? numberRows : azertyRows

        for row in currentRows {
            let rowStack = UIStackView()
            rowStack.axis = .horizontal
            rowStack.distribution = .fillEqually
            rowStack.spacing = 6

            for key in row {
                rowStack.addArrangedSubview(createKeyButton(title: key))
            }
            mainStackView.addArrangedSubview(rowStack)
        }

        updatePredictions()
    }

    private func createKeyButton(title: String) -> UIButton {
        let button = UIButton(type: .custom)
        button.layer.cornerRadius = 8
        button.titleLabel?.font = UIFont.systemFont(ofSize: 22, weight: .medium)

        switch title {
        case "SHIFT":
            button.setTitle(isUppercase ? "⇧ MAJ" : "⇧ min", for: .normal)
            button.backgroundColor = isUppercase ? UIColor.systemBlue : UIColor.systemGray3
            button.setTitleColor(isUppercase ? .white : .black, for: .normal)
        case "DEL":
            button.setTitle("⌫", for: .normal)
            button.backgroundColor = UIColor.systemGray3
            button.setTitleColor(.black, for: .normal)
        case "123", "ABC":
            button.setTitle(title, for: .normal)
            button.backgroundColor = UIColor.systemGray3
            button.setTitleColor(.black, for: .normal)
        case "SPACE":
            button.setTitle("Espace", for: .normal)
            button.backgroundColor = .white
            button.setTitleColor(.black, for: .normal)
        case "RETURN":
            button.setTitle("↵", for: .normal)
            button.backgroundColor = UIColor.systemBlue
            button.setTitleColor(.white, for: .normal)
        default:
            let displayChar = isUppercase ? title.uppercased() : title.lowercased()
            button.setTitle(displayChar, for: .normal)
            button.backgroundColor = .white
            button.setTitleColor(.black, for: .normal)
        }

        button.accessibilityIdentifier = title
        attachSwitchEvents(to: button, action: #selector(keyPressed(_:)))
        return button
    }

    private func currentWordPrefix() -> String {
        guard let before = textDocumentProxy.documentContextBeforeInput, !before.isEmpty else {
            return ""
        }
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

        for i in 0..<suggestionButtons.count {
            if i < suggestions.count {
                let word = suggestions[i]
                let formatted = (prefix.first?.isUppercase == true) ? word.prefix(1).uppercased() + word.dropFirst() : word
                suggestionButtons[i].setTitle(formatted, for: .normal)
            } else {
                suggestionButtons[i].setTitle("", for: .normal)
            }
        }
    }

    @objc private func predictionPressed(_ sender: UIButton) {
        let now = Date().timeIntervalSince1970
        if now - lastPressTime < debounceInterval { return }
        lastPressTime = now

        guard let chosenWord = sender.title(for: .normal), !chosenWord.isEmpty else { return }
        let prefix = currentWordPrefix()
        for _ in 0..<prefix.count {
            textDocumentProxy.deleteBackward()
        }
        textDocumentProxy.insertText(chosenWord + " ")
        isUppercase = false
        setupKeyboardInterface()
    }

    @objc private func keyPressed(_ sender: UIButton) {
        let now = Date().timeIntervalSince1970
        if now - lastPressTime < debounceInterval { return }
        lastPressTime = now

        let originalColor = sender.backgroundColor
        sender.backgroundColor = UIColor.systemGray4
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            sender.backgroundColor = originalColor
        }

        guard let key = sender.accessibilityIdentifier else { return }

        switch key {
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
            let charToInsert = isUppercase ? key.uppercased() : key.lowercased()
            textDocumentProxy.insertText(charToInsert)
            if isUppercase && key.rangeOfCharacter(from: .letters) != nil {
                isUppercase = false
                setupKeyboardInterface()
            } else {
                updatePredictions()
            }
        }
    }
}
