//
//  AspectInterpretation.swift
//  StarPath
//
//  Astrological interpretation data for aspects, ingresses, and stations.
//  Light-touch keywords to help users make sense of planetary events.
//

import Foundation

// MARK: - Aspect Keywords (Planet Pairs)

func aspectKeywords(bodyA: String, bodyB: String, aspectAngle: Double) -> String {
    let pair = Set([bodyA, bodyB])
    let isConjunction = aspectAngle == 0

    // Specific planet-pair interpretations
    if let specific = pairKeywords[pair] {
        return isConjunction ? specific.conjunction : specific.opposition
    }

    // Generic aspect-type fallback
    switch aspectAngle {
    case 0:   return "Merging energies"
    case 180: return "Awareness through polarity"
    case 90:  return "Creative tension"
    case 120: return "Flowing harmony"
    case 60:  return "Gentle opportunity"
    default:  return "Planetary alignment"
    }
}

private struct PairKeywords {
    let conjunction: String
    let opposition: String
}

private let pairKeywords: [Set<String>: PairKeywords] = [
    // Outer × Outer (generational)
    ["saturn", "neptune"]:  PairKeywords(conjunction: "Dissolving old structures", opposition: "Reality vs. imagination"),
    ["saturn", "uranus"]:   PairKeywords(conjunction: "Restructuring through disruption", opposition: "Tradition vs. revolution"),
    ["saturn", "jupiter"]:  PairKeywords(conjunction: "New social order begins", opposition: "Expansion meets limitation"),
    ["jupiter", "neptune"]: PairKeywords(conjunction: "Spiritual vision expands", opposition: "Faith tested by reality"),
    ["jupiter", "uranus"]:  PairKeywords(conjunction: "Sudden expansion, breakthroughs", opposition: "Freedom vs. growth"),
    ["uranus", "neptune"]:  PairKeywords(conjunction: "Collective awakening", opposition: "Innovation vs. dissolution"),

    // Mars × Outer
    ["mars", "saturn"]:  PairKeywords(conjunction: "Disciplined action", opposition: "Effort meets resistance"),
    ["mars", "jupiter"]: PairKeywords(conjunction: "Bold initiative, confidence", opposition: "Overreach vs. restraint"),
    ["mars", "uranus"]:  PairKeywords(conjunction: "Sudden action, breakthrough", opposition: "Impulse vs. independence"),
    ["mars", "neptune"]: PairKeywords(conjunction: "Inspired action, subtle force", opposition: "Drive vs. surrender"),

    // Venus × Outer
    ["venus", "saturn"]:  PairKeywords(conjunction: "Committed love, lasting bonds", opposition: "Desire meets duty"),
    ["venus", "jupiter"]: PairKeywords(conjunction: "Abundant affection, generosity", opposition: "Indulgence vs. values"),
    ["venus", "uranus"]:  PairKeywords(conjunction: "Unexpected attraction, freedom in love", opposition: "Stability vs. excitement"),
    ["venus", "neptune"]: PairKeywords(conjunction: "Idealized beauty, creative vision", opposition: "Romance vs. illusion"),
    ["venus", "mars"]:    PairKeywords(conjunction: "Desire and attraction unite", opposition: "Passion meets balance"),

    // Mercury × Outer
    ["mercury", "saturn"]:  PairKeywords(conjunction: "Serious thinking, clear structure", opposition: "Ideas vs. limitations"),
    ["mercury", "jupiter"]: PairKeywords(conjunction: "Big ideas, expansive thinking", opposition: "Detail vs. big picture"),
    ["mercury", "uranus"]:  PairKeywords(conjunction: "Flash of insight, mental awakening", opposition: "Logic vs. intuition"),
    ["mercury", "neptune"]: PairKeywords(conjunction: "Poetic thinking, imagination", opposition: "Clarity vs. confusion"),
    ["mercury", "mars"]:    PairKeywords(conjunction: "Sharp words, decisive thought", opposition: "Mind vs. action"),
    ["mercury", "venus"]:   PairKeywords(conjunction: "Graceful expression, diplomacy", opposition: "Thought vs. feeling"),

    // Sun × Planets
    ["sun", "moon"]:    PairKeywords(conjunction: "New beginnings, seed moment", opposition: "Illumination, culmination"),
    ["sun", "mercury"]: PairKeywords(conjunction: "Mind aligned with purpose", opposition: "Self-expression vs. reason"),
    ["sun", "venus"]:   PairKeywords(conjunction: "Heart aligned with purpose", opposition: "Identity vs. relationship"),
    ["sun", "mars"]:    PairKeywords(conjunction: "Vitality and drive unite", opposition: "Will meets resistance"),
    ["sun", "jupiter"]: PairKeywords(conjunction: "Confidence and expansion", opposition: "Ego vs. growth"),
    ["sun", "saturn"]:  PairKeywords(conjunction: "Purpose meets discipline", opposition: "Authority vs. identity"),
    ["sun", "uranus"]:  PairKeywords(conjunction: "Awakening, individuation", opposition: "Self vs. freedom"),
    ["sun", "neptune"]: PairKeywords(conjunction: "Spiritual clarity or confusion", opposition: "Identity dissolves to reform"),

    // Moon × Planets (frequent but still meaningful)
    ["moon", "mercury"]: PairKeywords(conjunction: "Feeling meets thought", opposition: "Emotion vs. logic"),
    ["moon", "venus"]:   PairKeywords(conjunction: "Emotional warmth, comfort", opposition: "Needs vs. desires"),
    ["moon", "mars"]:    PairKeywords(conjunction: "Emotional intensity, courage", opposition: "Feelings vs. action"),
    ["moon", "jupiter"]: PairKeywords(conjunction: "Emotional generosity", opposition: "Comfort vs. expansion"),
    ["moon", "saturn"]:  PairKeywords(conjunction: "Emotional discipline", opposition: "Needs vs. duty"),
    ["moon", "uranus"]:  PairKeywords(conjunction: "Emotional surprise", opposition: "Security vs. change"),
    ["moon", "neptune"]: PairKeywords(conjunction: "Dreamy sensitivity", opposition: "Instinct vs. illusion"),
]

// MARK: - Sign Context

func signContext(bodyA: String, bodyB: String, at date: Date) -> String {
    let slowerBody = planetSpeedOrder(bodyB) > planetSpeedOrder(bodyA) ? bodyB : bodyA
    let lon = geocentricLongitudes(for: date).longitude(for: slowerBody)
    let sign = zodiacSign(fromLongitude: lon)
    let degInSign = normalizeAngle(lon).truncatingRemainder(dividingBy: 30)
    let deg = Int(degInSign)
    return "at \(deg)° \(sign.name)"
}

// MARK: - Significance

enum AspectSignificance: Comparable {
    case frequent    // moon involved
    case monthly     // inner × inner
    case yearly      // inner × outer
    case generational // outer × outer
}

func aspectSignificance(bodyA: String, bodyB: String) -> AspectSignificance {
    let a = planetSpeedOrder(bodyA)
    let b = planetSpeedOrder(bodyB)
    let slower = max(a, b)
    let faster = min(a, b)

    // Both outer (jupiter=4 and above)
    if faster >= 4 { return .generational }
    // One outer + one non-moon inner
    if slower >= 4 && faster >= 1 { return .yearly }
    // Moon involved
    if faster == 0 || slower == 0 { return .frequent }
    // Both inner
    return .monthly
}

/// Returns a speed tier: 0=moon, 1=sun/mercury/venus, 2=mars, 3=jupiter, 4=saturn, 5=uranus, 6=neptune
private func planetSpeedOrder(_ body: String) -> Int {
    switch body {
    case "moon":    return 0
    case "sun":     return 1
    case "mercury": return 1
    case "venus":   return 1
    case "mars":    return 2
    case "jupiter": return 3
    case "saturn":  return 4
    case "uranus":  return 5
    case "neptune": return 6
    default:        return 0
    }
}

// MARK: - Applying vs Separating

func aspectPhase(bodyA: String, bodyB: String, aspectAngle: Double, at date: Date) -> String {
    let now = date
    let later = date.addingTimeInterval(86_400)

    let lonA1 = geocentricLongitudes(for: now).longitude(for: bodyA)
    let lonB1 = geocentricLongitudes(for: now).longitude(for: bodyB)
    let lonA2 = geocentricLongitudes(for: later).longitude(for: bodyA)
    let lonB2 = geocentricLongitudes(for: later).longitude(for: bodyB)

    let orbNow: Double
    let orbLater: Double

    if aspectAngle == 0 {
        orbNow = abs(signedDelta(lonA1, lonB1))
        orbLater = abs(signedDelta(lonA2, lonB2))
    } else {
        orbNow = abs(abs(signedDelta(lonA1, lonB1)) - aspectAngle)
        orbLater = abs(abs(signedDelta(lonA2, lonB2)) - aspectAngle)
    }

    if orbNow < 0.1 {
        return "Exact"
    } else if orbLater < orbNow {
        return "Applying"
    } else {
        return "Separating"
    }
}

// MARK: - Ingress Interpretation

func ingressKeywords(body: String, signIndex: Int) -> String {
    let sign = zodiacSigns[signIndex]

    // Planet-specific ingress meanings
    if let bodyKeywords = ingressLookup[body], let meaning = bodyKeywords[signIndex] {
        return meaning
    }

    // Generic: element-based
    let element: String
    switch signIndex % 4 {
    case 0: element = "fire"
    case 1: element = "earth"
    case 2: element = "air"
    case 3: element = "water"
    default: element = ""
    }

    let bodyName = celestialBodies.first(where: { $0.id == body })?.name ?? body.capitalized
    return "\(bodyName) enters \(element) — \(sign.glyph)\u{FE0E} \(sign.name)"
}

/// Key ingress interpretations for slower-moving planets
private let ingressLookup: [String: [Int: String]] = [
    "saturn": [
        0: "Discipline meets initiative",
        1: "Building lasting foundations",
        2: "Structuring communication",
        3: "Foundations of security",
        4: "Authority finds expression",
        5: "Refining systems and health",
        6: "Commitment in relationships",
        7: "Deepening through limits",
        8: "Structuring beliefs",
        9: "Ambition crystallizes",
        10: "Reforming collective ideals",
        11: "Dissolving to rebuild",
    ],
    "jupiter": [
        0: "Bold expansion begins",
        1: "Material growth and abundance",
        2: "Ideas multiply and spread",
        3: "Emotional generosity grows",
        4: "Creative confidence shines",
        5: "Wisdom in the details",
        6: "Growth through partnership",
        7: "Transformation brings gifts",
        8: "Exploring wider horizons",
        9: "Ambition meets opportunity",
        10: "Collective vision expands",
        11: "Spiritual understanding deepens",
    ],
    "mars": [
        0: "Drive and courage ignite",
        1: "Determined, steady effort",
        2: "Sharp words, quick moves",
        3: "Protective action rises",
        4: "Passionate self-expression",
        5: "Precision and focus sharpen",
        6: "Fighting for fairness",
        7: "Intense willpower stirs",
        8: "Adventurous action calls",
        9: "Strategic ambition builds",
        10: "Fighting for ideals",
        11: "Intuitive, inspired action",
    ],
]

// MARK: - Station Interpretation

func stationKeywords(body: String, isRetrograde: Bool) -> String {
    if isRetrograde {
        switch body {
        case "mercury": return "Review communications and plans"
        case "venus":   return "Reassess values and relationships"
        case "mars":    return "Redirect energy and ambition"
        case "jupiter": return "Reflect on growth and beliefs"
        case "saturn":  return "Revisit structures and commitments"
        case "uranus":  return "Inner revolution stirs"
        case "neptune": return "Dreams turn inward"
        default:        return "Apparent retrograde begins"
        }
    } else {
        switch body {
        case "mercury": return "Clarity returns to thought and travel"
        case "venus":   return "Love and values move forward"
        case "mars":    return "Action resumes with fresh direction"
        case "jupiter": return "Expansion and faith renew"
        case "saturn":  return "Progress on commitments resumes"
        case "uranus":  return "Change accelerates outward"
        case "neptune": return "Imagination flows freely again"
        default:        return "Forward motion resumes"
        }
    }
}

// MARK: - Significance Label

func significanceLabel(_ sig: AspectSignificance) -> String? {
    switch sig {
    case .generational: return "Rare"
    case .yearly:       return nil
    case .monthly:      return nil
    case .frequent:     return nil
    }
}
