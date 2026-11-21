import UIKit
import NaturalLanguage

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

    func animateFeedback(highlightColor: UIColor) {
        let savedColor = defaultColor
        backgroundColor = highlightColor
        UIView.animate(withDuration: 0.08, animations: {
            self.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
        }) { _ in
            UIView.animate(withDuration: 0.10) {
                self.transform = .identity
                self.backgroundColor = savedColor
            }
        }
    }
}

class NeuralFrenchPredictionEngine {
    private let textChecker = UITextChecker()
    private let tagger = NLTagger(tagSchemes: [.lexicalClass])
    private let defaults = UserDefaults.standard

    private let unigramKey = "user_unigram_freq_v2"
    private let bigramKey = "user_bigram_freq_v2"
    private let trigramKey = "user_trigram_freq_v2"

    private var userUnigrams: [String: Int] = [:]
    private var userBigrams: [String: [String: Int]] = [:]
    private var userTrigrams: [String: [String: Int]] = [:]

    private let azertyNeighbors: [Character: Set<Character>] = [
        "a": ["z", "q"], "z": ["a", "e", "q", "s"], "e": ["z", "r", "s", "d"],
        "r": ["e", "t", "d", "f"], "t": ["r", "y", "f", "g"], "y": ["t", "u", "g", "h"],
        "u": ["y", "i", "h", "j"], "i": ["u", "o", "j", "k"], "o": ["i", "p", "k", "l"],
        "p": ["o", "l", "m"], "q": ["a", "z", "s", "w"], "s": ["q", "z", "e", "d", "w", "x"],
        "d": ["s", "e", "r", "f", "x", "c"], "f": ["d", "r", "t", "g", "c", "v"],
        "g": ["f", "t", "y", "h", "v", "b"], "h": ["g", "y", "u", "j", "b", "n"],
        "j": ["h", "u", "i", "k", "n"], "k": ["j", "i", "o", "l"],
        "l": ["k", "o", "p", "m"], "m": ["l", "p"],
        "w": ["q", "s", "x"], "x": ["w", "s", "d", "c"], "c": ["x", "d", "f", "v"],
        "v": ["c", "f", "g", "b"], "b": ["v", "g", "h", "n"], "n": ["b", "h", "j"]
    ]

    private let coreLexicon: [String] = [
        "je", "tu", "il", "elle", "on", "nous", "vous", "ils", "elles",
        "le", "la", "les", "un", "une", "des", "du", "de", "au", "aux",
        "ce", "cet", "cette", "ces", "mon", "ton", "son", "ma", "ta", "sa", "mes", "tes", "ses", "notre", "votre", "leur", "leurs",
        "que", "qui", "quoi", "dont", "où", "quand", "comment", "pourquoi", "combien", "quel", "quelle", "quels", "quelles",
        "et", "ou", "mais", "donc", "car", "si", "alors", "aussi", "très", "trop", "bien", "mal", "peu", "beaucoup", "plus", "moins",
        "dans", "sur", "sous", "avec", "sans", "pour", "par", "vers", "chez", "entre", "avant", "après", "depuis", "pendant", "contre",
        "suis", "es", "est", "sommes", "êtes", "sont", "étais", "était", "étions", "étiez", "étaient", "serai", "sera", "serons", "serez", "seront", "être", "été",
        "ai", "as", "a", "avons", "avez", "ont", "avais", "avait", "avions", "aviez", "avaient", "aurai", "aura", "aurons", "aurez", "auront", "avoir", "eu",
        "vais", "vas", "va", "allons", "allez", "vont", "allais", "allait", "irai", "ira", "aller", "allé", "allée",
        "fais", "fait", "faisons", "faites", "font", "faisais", "faisait", "ferai", "fera", "faire",
        "peux", "peut", "pouvons", "pouvez", "peuvent", "pouvais", "pouvait", "pourrai", "pourra", "pouvoir", "pu",
        "veux", "veut", "voulons", "voulez", "veulent", "voulais", "voulait", "voudrais", "voudrait", "vouloir", "voulu",
        "dois", "doit", "devons", "devez", "doivent", "devais", "devait", "devrai", "devra", "devoir", "dû",
        "sais", "sait", "savons", "savez", "savent", "savais", "savait", "saura", "savoir", "su",
        "vois", "voit", "voyons", "voyez", "voient", "voyais", "voyait", "verrai", "verra", "voir", "vu",
        "prends", "prend", "prenons", "prenez", "prennent", "prenais", "prenait", "prendrai", "prendre", "pris",
        "viens", "vient", "venons", "venez", "viennent", "venais", "venait", "viendrai", "venir", "venu",
        "dis", "dit", "disons", "dites", "disent", "disais", "disait", "dirai", "dire",
        "mets", "met", "mettons", "mettez", "mettent", "mettais", "mettait", "mettrai", "mettre", "mis",
        "pense", "penses", "pensons", "pensez", "pensent", "penser", "pensé",
        "crois", "croit", "croyons", "croyez", "croient", "croire", "cru",
        "trouve", "trouves", "trouvons", "trouvez", "trouvent", "trouver", "trouvé",
        "donne", "donnes", "donnons", "donnez", "donnent", "donner", "donné",
        "parle", "parles", "parlons", "parlez", "parlent", "parler", "parlé",
        "aime", "aimes", "aimons", "aimez", "aiment", "aimer", "aimé",
        "demande", "demandes", "demandons", "demandez", "demandent", "demander", "demandé",
        "passe", "passes", "passons", "passez", "passent", "passer", "passé",
        "reste", "restes", "restons", "restez", "restent", "rester", "resté",
        "arrive", "arrives", "arrivons", "arrivez", "arrivent", "arriver", "arrivé",
        "regarde", "regardes", "regardons", "regardez", "regardent", "regarder", "regardé",
        "attends", "attend", "attendons", "attendez", "attendent", "attendre", "attendu",
        "comprends", "comprend", "comprenons", "comprenez", "comprennent", "comprendre", "compris",
        "bonjour", "salut", "coucou", "bonsoir", "merci", "oui", "non", "ok", "d'accord", "pardon", "excuse", "s'il", "plaît",
        "aujourd'hui", "demain", "hier", "maintenant", "bientôt", "toujours", "jamais", "souvent", "parfois", "déjà", "encore", "ensuite", "enfin",
        "tout", "tous", "toute", "toutes", "rien", "personne", "quelque", "chose", "quelqu'un", "chaque", "plusieurs",
        "bon", "bonne", "bons", "bonnes", "petit", "petite", "grand", "grande", "nouveau", "nouvelle", "vieux", "vieille", "autre", "autres", "même", "mêmes",
        "super", "génial", "parfait", "content", "contente", "fatigué", "fatiguée", "prêt", "prête", "sûr", "sûre", "vrai", "faux", "possible", "impossible",
        "temps", "jour", "jours", "fois", "heure", "heures", "minute", "minutes", "semaine", "mois", "ans", "année", "matin", "midi", "soir", "nuit",
        "monde", "vie", "main", "mains", "tête", "cœur", "yeux", "maison", "chambre", "porte", "table", "lit", "voiture", "fauteuil", "batterie",
        "téléphone", "ipad", "écran", "clavier", "message", "photo", "vidéo", "musique", "internet", "wifi", "application",
        "travail", "école", "cours", "problème", "question", "réponse", "idée", "besoin", "envie", "peur", "raison", "place", "fin", "début", "coup", "aide"
    ]

    private let transitions: [String: [String]] = [
        "je": ["suis", "vais", "veux", "peux", "dois", "sais", "pense", "crois", "vois", "fais"],
        "j'": ["ai", "aime", "espère", "arrive", "attends", "écoute", "envoie"],
        "tu": ["es", "vas", "peux", "veux", "as", "fais", "sais", "viens"],
        "il": ["est", "a", "va", "peut", "veut", "fait", "faut", "y"],
        "elle": ["est", "a", "va", "peut", "veut", "fait"],
        "on": ["est", "va", "peut", "a", "fait", "se"],
        "nous": ["sommes", "avons", "allons", "pouvons", "voulons", "faisons"],
        "vous": ["êtes", "avez", "pouvez", "voulez", "allez", "faites"],
        "ils": ["sont", "ont", "vont", "peuvent", "veulent", "font"],
        "elles": ["sont", "ont", "vont", "peuvent", "veulent", "font"],
        "ça": ["va", "marche", "fait", "peut", "sera", "est"],
        "c'": ["est", "était", "est-ce"],
        "c'est": ["bon", "parfait", "super", "vrai", "possible", "gentil", "bien", "quoi"],
        "ce": ["n'est", "qui", "que", "soir", "matin"],
        "n'": ["est", "ai", "a", "ont", "importe"],
        "ne": ["pas", "sais", "peux", "veux", "t'inquiète"],
        "pas": ["de", "du", "mal", "encore", "toujours", "vraiment", "possible"],
        "de": ["la", "le", "faire", "voir", "dire", "mon", "ton", "tout"],
        "du": ["coup", "temps", "monde", "tout"],
        "des": ["gens", "choses", "questions", "nouvelles"],
        "à": ["la", "demain", "tout", "bientôt", "ce", "mon", "ton"],
        "au": ["top", "moins", "revoir", "fait", "début"],
        "en": ["fait", "train", "ce", "plus", "avance", "retard", "haut", "bas"],
        "pour": ["le", "la", "moi", "toi", "vous", "faire", "dire", "voir"],
        "dans": ["le", "la", "les", "un", "une", "mon", "ma"],
        "avec": ["le", "la", "mon", "ma", "toi", "vous", "plaisir"],
        "sur": ["le", "la", "mon", "ma", "l'ipad"],
        "et": ["toi", "vous", "je", "on", "puis", "aussi"],
        "mais": ["je", "c'est", "il", "on", "tu", "bon"],
        "si": ["tu", "on", "c'est", "je", "vous"],
        "quand": ["tu", "on", "même", "je", "vous"],
        "comment": ["ça", "vas-tu", "tu", "faire", "on"],
        "pourquoi": ["pas", "tu", "il", "on", "c'est"],
        "bonjour": ["comment", "ça", "à", "tout"],
        "salut": ["comment", "ça", "tu", "à"],
        "merci": ["beaucoup", "pour", "à", "d'avance", "bien"],
        "s'il": ["te", "vous"],
        "te": ["plaît", "dire", "voir", "faire"],
        "vous": ["plaît", "êtes", "avez", "pouvez"],
        "je suis": ["en", "là", "prêt", "fatigué", "content", "bien", "sur", "dans"],
        "je vais": ["bien", "voir", "faire", "aller", "prendre", "me"],
        "je veux": ["bien", "dire", "aller", "faire", "voir", "un", "une"],
        "je peux": ["avoir", "faire", "aller", "voir", "te", "vous"],
        "j'ai": ["besoin", "envie", "fait", "un", "une", "pas", "bien", "mal"],
        "ça va": ["bien", "et", "merci", "être", "aller"],
        "il y": ["a", "avait", "aura"],
        "y": ["a", "va", "crois", "pense"],
        "en train": ["de"],
        "besoin": ["de", "d'aide"],
        "envie": ["de", "d'aller"]
    ]

    // Auto-correction silencieuse quand on appuie sur Espace après un mot sans accent
    private let autoCorrectMap: [String: String] = [
        "ca": "ça",
        "etre": "être",
        "ete": "été",
        "deja": "déjà",
        "tres": "très",
        "apres": "après",
        "voila": "voilà",
        "peut-etre": "peut-être",
        "bientot": "bientôt",
        "plait": "plaît",
        "telephone": "téléphone",
        "ecran": "écran",
        "probleme": "problème",
        "reponse": "réponse",
        "idee": "idée",
        "fatigue": "fatigué",
        "pret": "prêt",
        "genial": "génial"
    ]

    private let accentShortcuts: [String: [String]] = [
        "ca": ["ça", "cas", "car"],
        "etre": ["être", "êtres"],
        "ete": ["été", "êtes"],
        "deja": ["déjà"],
        "tres": ["très"],
        "apres": ["après"],
        "a": ["à", "a", "as"],
        "ou": ["où", "ou"],
        "la": ["la", "là"],
        "des": ["des", "dès"],
        "du": ["du", "dû"],
        "sur": ["sur", "sûr"],
        "voila": ["voilà"],
        "peut-etre": ["peut-être"],
        "bientot": ["bientôt"],
        "aujourd": ["aujourd'hui"],
        "accord": ["d'accord"]
    ]

    private lazy var baseRank: [String: Int] = {
        var map: [String: Int] = [:]
        for (i, w) in coreLexicon.enumerated() {
            map[w] = i
        }
        return map
    }()

    init() {
        if let savedUni = defaults.dictionary(forKey: unigramKey) as? [String: Int] {
            userUnigrams = savedUni
        }
        if let savedBi = defaults.dictionary(forKey: bigramKey) as? [String: [String: Int]] {
            userBigrams = savedBi
        }
        if let savedTri = defaults.dictionary(forKey: trigramKey) as? [String: [String: Int]] {
            userTrigrams = savedTri
        }
    }

    func autoCorrectionForLastWord(in context: String?) -> (original: String, corrected: String)? {
        guard let before = context, !before.isEmpty, before.last?.isWhitespace == false else { return nil }
        let tokens = tokenize(before)
        guard let last = tokens.last else { return nil }
        let lower = last.lowercased()
        guard let fixed = autoCorrectMap[lower], fixed != lower else { return nil }
        let isCap = last.first?.isUppercase == true
        return (last, applyCase(fixed, capitalize: isCap))
    }

    func learn(fromContextBefore context: String?) {
        guard let before = context, !before.isEmpty else { return }
        let tokens = tokenize(before)
        guard let last = tokens.last, !last.isEmpty else { return }

        let w3 = last.lowercased()
        userUnigrams[w3, default: 0] += 1

        if tokens.count >= 2 {
            let w2 = tokens[tokens.count - 2].lowercased()
            var nextMap = userBigrams[w2] ?? [:]
            nextMap[w3, default: 0] += 2
            userBigrams[w2] = nextMap
        }

        if tokens.count >= 3 {
            let w1 = tokens[tokens.count - 3].lowercased()
            let w2 = tokens[tokens.count - 2].lowercased()
            let pairKey = "\(w1) \(w2)"
            var triMap = userTrigrams[pairKey] ?? [:]
            triMap[w3, default: 0] += 3
            userTrigrams[pairKey] = triMap
        }

        defaults.set(userUnigrams, forKey: unigramKey)
        defaults.set(userBigrams, forKey: bigramKey)
        defaults.set(userTrigrams, forKey: trigramKey)
    }

    func predict(contextBefore: String?) -> (suggestions: [String], replacingPrefix: String) {
        guard let before = contextBefore, !before.isEmpty else {
            return (["Bonjour", "Je", "Ça"], "")
        }

        let trimmedRight = before.trimmingCharacters(in: .whitespacesAndNewlines)
        let endsWithSpace = before.last?.isWhitespace == true

        // CAS 1 : Après un espace -> Prédiction contextuelle du mot suivant (Trigrammes > Bigrammes > Grammaire)
        if endsWithSpace {
            if trimmedRight.hasSuffix(".") || trimmedRight.hasSuffix("?") || trimmedRight.hasSuffix("!") {
                return (["Je", "On", "C'est"], "")
            }

            let tokens = tokenize(trimmedRight)
            guard let lastRaw = tokens.last else {
                return (["Bonjour", "Je", "Oui"], "")
            }

            let lastWord = lastRaw.lowercased()
            var scoredNext: [(word: String, score: Double)] = []

            // 1. Trigrammes appris de l'utilisateur (ex: "je suis" -> "là")
            if tokens.count >= 2 {
                let twoWords = "\(tokens[tokens.count - 2].lowercased()) \(lastWord)"
                if let learnedTri = userTrigrams[twoWords] {
                    for (w, count) in learnedTri {
                        scoredNext.append((w, 260.0 + Double(count) * 30.0))
                    }
                }
            }

            // 2. Bigrammes appris de l'utilisateur
            if let learnedNext = userBigrams[lastWord] {
                for (w, count) in learnedNext {
                    scoredNext.append((w, 200.0 + Double(count) * 25.0))
                }
            }

            // 3. Transitions intégrées sur 2 mots
            if tokens.count >= 2 {
                let twoWords = "\(tokens[tokens.count - 2].lowercased()) \(lastWord)"
                if let pairMatches = transitions[twoWords] {
                    for (idx, w) in pairMatches.enumerated() {
                        scoredNext.append((w, 160.0 - Double(idx) * 10.0))
                    }
                }
            }

            // 4. Transitions intégrées sur 1 mot
            if let nextMatches = transitions[lastWord] {
                for (idx, w) in nextMatches.enumerated() {
                    scoredNext.append((w, 130.0 - Double(idx) * 8.0))
                }
            }

            // 5. Analyse grammaticale Apple NaturalLanguage (NLTagger)
            let expectedTags = expectedNextPOS(after: trimmedRight)
            if !expectedTags.isEmpty {
                for (idx, candidate) in coreLexicon.prefix(90).enumerated() {
                    let tag = lexicalTag(for: candidate)
                    if expectedTags.contains(tag) {
                        scoredNext.append((candidate, 85.0 - Double(idx) * 0.4))
                    }
                }
            }

            let merged = deduplicateAndSort(scoredNext)
            if merged.count >= 3 {
                return (Array(merged.prefix(3)), "")
            }

            let fallbacks = ["de", "et", "à", "le", "que"]
            var result = merged
            for fb in fallbacks where !result.contains(fb) {
                result.append(fb)
            }
            return (Array(result.prefix(3)), "")
        }

        // CAS 2 : Mot en cours de frappe -> Complétion + Correction intelligente
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
            let base = transitions[key] ?? ["est", "ai", "un"]
            let formatted = base.prefix(3).map { applyCase(elisionPrefix + $0, capitalize: isCapitalized) }
            return (Array(formatted), currentToken)
        }

        let beforeCurrentToken = String(before.dropLast(currentToken.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        let prevTokens = tokenize(beforeCurrentToken)
        let prevWord = prevTokens.last?.lowercased() ?? ""
        let prevTwoWords = prevTokens.count >= 2 ? "\(prevTokens[prevTokens.count - 2].lowercased()) \(prevWord)" : ""
        let expectedTags = beforeCurrentToken.isEmpty ? [.pronoun, .interjection] : expectedNextPOS(after: beforeCurrentToken)

        var scoredCandidates: [(word: String, score: Double)] = []

        if let shortcuts = accentShortcuts[lowerSearch] {
            for (idx, w) in shortcuts.enumerated() {
                scoredCandidates.append((w, 260.0 - Double(idx) * 15.0))
            }
        }

        for (w, count) in userUnigrams where w.hasPrefix(lowerSearch) {
            var bonus = 180.0 + Double(count) * 15.0
            if let biCount = userBigrams[prevWord]?[w] {
                bonus += Double(biCount) * 40.0
            }
            if !prevTwoWords.isEmpty, let triCount = userTrigrams[prevTwoWords]?[w] {
                bonus += Double(triCount) * 60.0
            }
            scoredCandidates.append((w, bonus))
        }

        let expectedFromPrev = Set(transitions[prevWord] ?? [])
        for (idx, w) in coreLexicon.enumerated() where w.hasPrefix(lowerSearch) {
            var score = 150.0 - Double(idx) * 0.45
            if w == lowerSearch { score += 25.0 }
            if expectedFromPrev.contains(w) { score += 55.0 }
            if !expectedTags.isEmpty && expectedTags.contains(lexicalTag(for: w)) {
                score += 30.0
            }
            scoredCandidates.append((w, score))
        }

        let nsSearch = searchWord as NSString
        let range = NSRange(location: 0, length: nsSearch.length)
        if let iosCompletions = textChecker.completions(forPartialWordRange: range, in: searchWord, language: "fr_FR") {
            for w in iosCompletions.prefix(20) {
                let lw = w.lowercased()
                let freqBonus = (baseRank[lw] != nil) ? 40.0 : 0.0
                let lengthPenalty = Double(max(0, w.count - searchWord.count)) * 1.5
                scoredCandidates.append((w, 95.0 + freqBonus - lengthPenalty))
            }
        }

        if lowerSearch.count >= 2 {
            if let guesses = textChecker.guesses(forWordRange: range, in: searchWord, language: "fr_FR") {
                for (idx, guess) in guesses.prefix(5).enumerated() {
                    let proximityBonus = isAzertyNeighborTypo(typed: lowerSearch, candidate: guess.lowercased()) ? 65.0 : 20.0
                    scoredCandidates.append((guess, 90.0 + proximityBonus - Double(idx) * 8.0))
                }
            }
        }

        if !scoredCandidates.contains(where: { $0.word.caseInsensitiveCompare(searchWord) == .orderedSame }) {
            scoredCandidates.append((searchWord, 80.0))
        }

        let sorted = deduplicateAndSort(scoredCandidates)
        let finalSuggestions = sorted.prefix(3).map { word in
            applyCase(elisionPrefix + word, capitalize: isCapitalized)
        }

        return (Array(finalSuggestions), currentToken)
    }

    private func expectedNextPOS(after text: String) -> Set<NLTag> {
        let tokens = tokenize(text)
        guard let last = tokens.last else { return [.pronoun] }
        let tag = lexicalTag(for: last)

        switch tag {
        case .pronoun:
            return [.verb]
        case .determiner:
            return [.noun, .adjective]
        case .preposition:
            return [.determiner, .noun, .verb, .pronoun]
        case .verb:
            return [.adverb, .determiner, .preposition, .pronoun, .adjective]
        case .noun:
            return [.adjective, .verb, .preposition, .conjunction]
        default:
            return []
        }
    }

    private func lexicalTag(for word: String) -> NLTag {
        tagger.string = word
        let (tag, _) = tagger.tag(at: word.startIndex, unit: .word, scheme: .lexicalClass)
        return tag ?? .other
    }

    private func isAzertyNeighborTypo(typed: String, candidate: String) -> Bool {
        guard typed.count == candidate.count else { return false }
        var diffs = 0
        for (c1, c2) in zip(typed, candidate) where c1 != c2 {
            diffs += 1
            if diffs > 1 { return false }
            if !(azertyNeighbors[c1]?.contains(c2) ?? false) {
                return false
            }
        }
        return diffs == 1
    }

    private func tokenize(_ text: String) -> [String] {
        let separators = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ".,!?;:\"()"))
        return text.components(separatedBy: separators).filter { !$0.isEmpty }
    }

    private func deduplicateAndSort(_ items: [(word: String, score: Double)]) -> [String] {
        var bestScores: [String: (display: String, score: Double)] = [:]
        for item in items {
            let key = item.word.lowercased()
            if let existing = bestScores[key] {
                if item.score > existing.score {
                    bestScores[key] = (item.word, item.score)
                }
            } else {
                bestScores[key] = (item.word, item.score)
            }
        }
        return bestScores.values
            .sorted { $0.score > $1.score }
            .map { $0.display }
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
    private var lastSpaceTime: TimeInterval = 0
    private let debounceInterval: TimeInterval = 0.30
    private var mainStackView: UIStackView!
    private var suggestionViews: [KeyView] = []
    private var currentReplacingPrefix: String = ""
    private let predictionEngine = NeuralFrenchPredictionEngine()

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
        ["123", "SPACE", ",", ".", "?", "RETURN"]
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
        case ",", ".", "?", "!":
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

        sender.animateFeedback(highlightColor: UIColor.systemBlue.withAlphaComponent(0.25))

        guard let chosenWord = sender.label.text, !chosenWord.isEmpty else { return }

        for _ in 0..<currentReplacingPrefix.count {
            textDocumentProxy.deleteBackward()
        }

        let suffix = chosenWord.hasSuffix("'") ? "" : " "
        textDocumentProxy.insertText(chosenWord + suffix)
        predictionEngine.learn(fromContextBefore: textDocumentProxy.documentContextBeforeInput)
        isUppercase = false
        setupKeyboardInterface()
    }

    private func keyPressed(_ sender: KeyView) {
        let now = Date().timeIntervalSince1970
        if now - lastPressTime < debounceInterval { return }
        lastPressTime = now

        sender.animateFeedback(highlightColor: UIColor.systemBlue.withAlphaComponent(0.22))

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
            let before = textDocumentProxy.documentContextBeforeInput ?? ""
            // Double-espace rapide (< 1,2 s) après un mot -> insère un point et passe en majuscule
            if now - lastSpaceTime < 1.2, before.hasSuffix(" "), before.count >= 2 {
                let prevChar = before[before.index(before.endIndex, offsetBy: -2)]
                if prevChar.isLetter || prevChar.isNumber {
                    textDocumentProxy.deleteBackward()
                    textDocumentProxy.insertText(". ")
                    lastSpaceTime = 0
                    isUppercase = true
                    setupKeyboardInterface()
                    return
                }
            }

            // Auto-correction silencieuse des accents oubliés avant d'insérer l'espace
            if let fix = predictionEngine.autoCorrectionForLastWord(in: before) {
                for _ in 0..<fix.original.count {
                    textDocumentProxy.deleteBackward()
                }
                textDocumentProxy.insertText(fix.corrected)
            }

            predictionEngine.learn(fromContextBefore: textDocumentProxy.documentContextBeforeInput)
            textDocumentProxy.insertText(" ")
            lastSpaceTime = now
            updatePredictions()
        case "RETURN":
            predictionEngine.learn(fromContextBefore: textDocumentProxy.documentContextBeforeInput)
            textDocumentProxy.insertText("\n")
            isUppercase = true
            setupKeyboardInterface()
        case ",", ".", "?", "!":
            predictionEngine.learn(fromContextBefore: textDocumentProxy.documentContextBeforeInput)
            if let before = textDocumentProxy.documentContextBeforeInput, before.hasSuffix(" ") {
                textDocumentProxy.deleteBackward()
            }
            textDocumentProxy.insertText(sender.keyIdentifier + " ")
            if sender.keyIdentifier != "," {
                isUppercase = true
                setupKeyboardInterface()
            } else {
                updatePredictions()
            }
        default:
            lastSpaceTime = 0
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
