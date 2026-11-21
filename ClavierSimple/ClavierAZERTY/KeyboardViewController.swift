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

class FrenchPredictionEngine {
    private let textChecker = UITextChecker()

    // Mots français les plus fréquents classés par priorité d'usage
    private let commonWords: [String] = [
        "je", "tu", "il", "elle", "on", "nous", "vous", "ils", "elles",
        "le", "la", "les", "un", "une", "des", "du", "de", "au", "aux",
        "ce", "cet", "cette", "ces", "mon", "ton", "son", "ma", "ta", "sa", "mes", "tes", "ses", "notre", "votre", "leur",
        "que", "qui", "quoi", "dont", "où", "quand", "comment", "pourquoi", "combien",
        "et", "ou", "mais", "donc", "or", "ni", "car", "si", "alors", "aussi", "très", "trop", "bien", "mal", "peu", "beaucoup",
        "dans", "sur", "sous", "avec", "sans", "pour", "par", "vers", "chez", "entre", "avant", "après", "depuis", "pendant",
        "suis", "es", "est", "sommes", "êtes", "sont", "étais", "était", "serai", "sera", "être", "été",
        "ai", "as", "a", "avons", "avez", "ont", "avais", "avait", "aurai", "aura", "avoir", "eu",
        "vais", "vas", "va", "allons", "allez", "vont", "aller", "allé",
        "fais", "fait", "faisons", "faites", "font", "faire",
        "peux", "peut", "pouvons", "pouvez", "peuvent", "pouvoir", "pu",
        "veux", "veut", "voulons", "voulez", "veulent", "vouloir", "voulu",
        "dois", "doit", "devons", "devez", "doivent", "devoir",
        "sais", "sait", "savons", "savez", "savent", "savoir",
        "vois", "voit", "voyons", "voyez", "voient", "voir", "vu",
        "prends", "prend", "prenons", "prenez", "prennent", "prendre", "pris",
        "viens", "vient", "venons", "venez", "viennent", "venir", "venu",
        "dis", "dit", "disons", "dites", "disent", "dire",
        "mets", "met", "mettons", "mettez", "mettent", "mettre", "mis",
        "bonjour", "salut", "coucou", "merci", "oui", "non", "ok", "d'accord", "pardon", "excuse", "s'il", "plaît",
        "aujourd'hui", "demain", "hier", "maintenant", "bientôt", "toujours", "jamais", "souvent", "parfois", "déjà", "encore",
        "tout", "tous", "toute", "toutes", "rien", "personne", "quelque", "chose", "quelqu'un",
        "bon", "bonne", "petit", "petite", "grand", "grande", "nouveau", "nouvelle", "vieux", "vieille", "autre", "même",
        "temps", "jour", "fois", "heure", "ans", "monde", "vie", "main", "tête", "cœur", "maison", "voiture", "fauteuil",
        "travail", "problème", "question", "idée", "besoin", "envie", "peur", "raison", "place", "fin", "début", "coup"
    ]

    // Prédiction contextuelle du mot suivant (Bigrammes français courants)
    private let nextWordMap: [String: [String]] = [
        "je": ["suis", "vais", "veux"],
        "j'": ["ai", "aime", "espère"],
        "tu": ["es", "vas", "peux"],
        "il": ["est", "a", "va"],
        "elle": ["est", "a", "va"],
        "on": ["est", "va", "peut"],
        "nous": ["sommes", "avons", "allons"],
        "vous": ["êtes", "avez", "pouvez"],
        "ils": ["sont", "ont", "vont"],
        "elles": ["sont", "ont", "vont"],
        "ça": ["va", "marche", "fait"],
        "c'": ["est", "était", "était"],
        "c'est": ["bon", "parfait", "super"],
        "ce": ["n'est", "qui", "que"],
        "n'": ["est", "ai", "a"],
        "ne": ["pas", "sais", "peux"],
        "pas": ["de", "du", "mal"],
        "de": ["la", "le", "faire"],
        "à": ["la", "demain", "tout"],
        "au": ["top", "moins", "revoir"],
        "en": ["fait", "train", "ce"],
        "pour": ["le", "la", "moi"],
        "dans": ["le", "la", "les"],
        "avec": ["le", "la", "mon"],
        "sur": ["le", "la", "mon"],
        "et": ["toi", "vous", "je"],
        "mais": ["je", "c'est", "il"],
        "si": ["tu", "on", "c'est"],
        "quand": ["tu", "on", "même"],
        "comment": ["ça", "vas-tu", "faire"],
        "pourquoi": ["pas", "tu", "il"],
        "bonjour": ["comment", "ça", "à"],
        "salut": ["comment", "ça", "tu"],
        "merci": ["beaucoup", "pour", "à"],
        "s'il": ["te", "vous", "plaît"],
        "te": ["plaît", "dire", "voir"],
        "vous": ["plaît", "êtes", "avez"],
        "je suis": ["en", "là", "prêt"],
        "je vais": ["bien", "voir", "faire"],
        "je veux": ["bien", "dire", "aller"],
        "j'ai": ["besoin", "envie", "fait"],
        "ça va": ["bien", "et", "merci"],
        "il y": ["a", "avait", "aura"],
        "y": ["a", "va", "crois"]
    ]

    private lazy var frequencyRank: [String: Int] = {
        var dict: [String: Int] = [:]
        for (idx, word) in commonWords.enumerated() {
            dict[word] = idx
        }
        return dict
    }()

    func predict(contextBefore: String?) -> (suggestions: [String], replacingPrefix: String) {
        guard let before = contextBefore, !before.isEmpty else {
            return (["Bonjour", "Je", "Ça"], "")
        }

        let trimmedRight = before.trimmingCharacters(in: .whitespacesAndNewlines)
        let endsWithSpace = before.last?.isWhitespace == true

        // Cas 1 : L'utilisateur vient de taper un espace -> prédire le MOT SUIVANT
        if endsWithSpace {
            let words = trimmedRight
                .components(separatedBy: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ".,!?;:\"()")))
                .filter { !$0.isEmpty }

            guard let lastRaw = words.last else {
                return (["Bonjour", "Je", "Oui"], "")
            }

            let lastWord = lastRaw.lowercased()

            // Vérifier d'abord une paire de 2 mots (ex: "je suis", "ça va", "il y")
            if words.count >= 2 {
                let twoWords = "\(words[words.count - 2].lowercased()) \(lastWord)"
                if let pairMatches = nextWordMap[twoWords] {
                    return (pairMatches, "")
                }
            }

            // Sinon vérifier le mot précédent seul
            if let nextMatches = nextWordMap[lastWord] {
                return (nextMatches, "")
            }

            // Après un point, proposer des débuts de phrase naturels
            if trimmedRight.hasSuffix(".") || trimmedRight.hasSuffix("?") || trimmedRight.hasSuffix("!") {
                return (["Je", "On", "C'est"], "")
            }

            return (["de", "et", "à"], "")
        }

        // Cas 2 : L'utilisateur est en train de taper un mot -> compléter / corriger
        let separators = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ".,!?;:\"()"))
        let currentToken: String
        if let range = before.rangeOfCharacter(from: separators, options: .backwards) {
            currentToken = String(before[range.upperBound...])
        } else {
            currentToken = before
        }

        if currentToken.isEmpty {
            return (["Bonjour", "Je", "Ça"], "")
        }

        // Gestion de l'apostrophe française (ex: "j'a" -> préfixe d'élision "j'", mot recherché "a")
        var elisionPrefix = ""
        var searchWord = currentToken
        if let aposIndex = currentToken.lastIndex(of: "'") {
            let afterApos = currentToken.index(after: aposIndex)
            elisionPrefix = String(currentToken[..<afterApos])
            searchWord = String(currentToken[afterApos...])
        }

        let lowerSearch = searchWord.lowercased()
        let isCapitalized = currentToken.first?.isUppercase == true

        if searchWord.isEmpty && !elisionPrefix.isEmpty {
            let key = elisionPrefix.lowercased()
            let base = nextWordMap[key] ?? ["est", "ai", "un"]
            let formatted = base.map { applyCase(elisionPrefix + $0, capitalize: isCapitalized) }
            return (Array(formatted.prefix(3)), currentToken)
        }

        var candidates: [String] = []

        // 1. Correspondances dans notre liste de fréquence française
        let frequentMatches = commonWords.filter { $0.hasPrefix(lowerSearch) && $0 != lowerSearch }
        candidates.append(contentsOf: frequentMatches)

        // 2. Complétions système iOS fr_FR
        let nsSearch = searchWord as NSString
        let range = NSRange(location: 0, length: nsSearch.length)
        if let iosCompletions = textChecker.completions(forPartialWordRange: range, in: searchWord, language: "fr_FR") {
            let sortedIOS = iosCompletions.sorted { a, b in
                let rankA = frequencyRank[a.lowercased()] ?? 9999
                let rankB = frequencyRank[b.lowercased()] ?? 9999
                if rankA != rankB { return rankA < rankB }
                return a.count < b.count
            }
            for word in sortedIOS where !candidates.contains(where: { $0.caseInsensitiveCompare(word) == .orderedSame }) {
                candidates.append(word)
            }
        }

        // 3. Corrections orthographiques / accents (ex: "ca" -> "ça", "etre" -> "être", "ou" -> "où")
        let misspelledRange = textChecker.rangeOfMisspelledWord(in: searchWord, range: range, startingAt: 0, wrap: false, language: "fr_FR")
        if misspelledRange.location != NSNotFound || lowerSearch.count >= 2 {
            if let guesses = textChecker.guesses(forWordRange: range, in: searchWord, language: "fr_FR") {
                for guess in guesses where !candidates.contains(where: { $0.caseInsensitiveCompare(guess) == .orderedSame }) {
                    candidates.insert(guess, at: min(1, candidates.count))
                }
            }
        }

        // Garantir que le mot exact tapé (ou avec accent) est accessible en 1re ou 2e position
        if !candidates.contains(where: { $0.caseInsensitiveCompare(searchWord) == .orderedSame }) {
            candidates.insert(searchWord, at: min(1, candidates.count))
        }

        let finalSuggestions = candidates.prefix(3).map { word in
            applyCase(elisionPrefix + word, capitalize: isCapitalized)
        }

        return (Array(finalSuggestions), currentToken)
    }

    private func applyCase(_ word: String, capitalize: Bool) -> String {
        guard capitalize, let first = word.first else { return word }
        return String(first).uppercased() + word.dropFirst()
    }
}

class KeyboardViewController: UIInputViewController {

    private var isUppercase = true
    private var isNumbers = false
    private var lastPressTime: TimeInterval = 0
    private let debounceInterval: TimeInterval = 0.30
    private var mainStackView: UIStackView!
    private var suggestionViews: [KeyView] = []
    private var currentReplacingPrefix: String = ""
    private let predictionEngine = FrenchPredictionEngine()

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
            kv.label.font = UIFont.systemFont(ofSize: 18, weight: .medium)
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

    private func updatePredictions() {
        let result = predictionEngine.predict(contextBefore: textDocumentProxy.documentContextBeforeInput)
        currentReplacingPrefix = result.replacingPrefix

        for i in 0..<suggestionViews.count {
            if i < result.suggestions.count {
                let word = result.suggestions[i]
                suggestionViews[i].label.text = word
                suggestionViews[i].accessibilityLabel = word
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

        for _ in 0..<currentReplacingPrefix.count {
            textDocumentProxy.deleteBackward()
        }

        let suffix = chosenWord.hasSuffix("'") ? "" : " "
        textDocumentProxy.insertText(chosenWord + suffix)
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
            isUppercase = true
            setupKeyboardInterface()
        case ".", "?", "!":
            // Supprime l'espace ajouté après une prédiction si on tape une ponctuation juste après
            if let before = textDocumentProxy.documentContextBeforeInput, before.hasSuffix(" ") {
                textDocumentProxy.deleteBackward()
            }
            textDocumentProxy.insertText(sender.keyIdentifier + " ")
            isUppercase = true
            setupKeyboardInterface()
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
