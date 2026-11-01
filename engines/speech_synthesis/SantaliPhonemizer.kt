
/**
 * Portable Santali (Ol Chiki) -> IPA / phoneme-token converter.
 *
 * Reference basis:
 * - Unicode Standard / Ol Chiki encoding documentation.
 * - Michael Everson, Ol Chiki encoding proposal N2984.
 * - Richard Ishida, Ol Chiki (Santali) Orthography Notes.
 * - Unicode CLDR Santali Ol Chiki -> FONIPA transliteration data.
 *
 * Design:
 * - No third-party dependencies.
 * - Deterministic and portable to Kotlin, Java, TypeScript, Rust, etc.
 * - santaliToIpa() returns a readable IPA representation.
 * - santaliToPhonemes() returns atomic IPA tokens for a Piper ID map.
 *
 * Phaarkaa is represented canonically as an ejective after the four relevant
 * consonants. There is no alternate mode in this file.
 */

import java.text.Normalizer

object SantaliPhonemizer {
    private val BASIC_CONSONANTS = mapOf(
        "ᱯ" to "p",
        "ᱵ" to "b",
        "ᱛ" to "t",
        "ᱫ" to "d",
        "ᱪ" to "c",
        "ᱰ" to "ɖ",
        "ᱴ" to "ʈ",
        "ᱡ" to "ɟ",
        "ᱠ" to "k",
        "ᱜ" to "ɡ",
        "ᱥ" to "s",
        "ᱦ" to "h",
        "ᱢ" to "m",
        "ᱱ" to "n",
        "ᱧ" to "ɲ",
        "ᱬ" to "ɳ",
        "ᱝ" to "ŋ",
        "ᱣ" to "w",
        "ᱶ" to "w̃",
        "ᱨ" to "r",
        "ᱲ" to "ɽ",
        "ᱞ" to "l",
        "ᱭ" to "j"
    )

    private val VOWEL_BASES = mapOf(
        "ᱤ" to "i",
        "ᱩ" to "u",
        "ᱮ" to "e",
        "ᱳ" to "o",
        "ᱚ" to "ɔ",
        "ᱟ" to "a"
    )

    private const val NASAL = "ᱸ"
    private const val DOT = "ᱹ"
    private const val NASAL_DOT = "ᱺ"
    private const val LONG = "ᱻ"
    private const val PHAARKAA = "ᱼ"
    private const val AHAD = "ᱽ"
    private const val ASPIRATION = "ᱷ"

    private val GLOTTALIZED = mapOf(
        "ᱵ" to Triple("b", "p̚", "pʼ"),
        "ᱡ" to Triple("ɟ", "c̚", "cʼ"),
        "ᱫ" to Triple("d", "t̚", "tʼ"),
        "ᱜ" to Triple("ɡ", "k̚", "kʼ")
    )

    private val PUNCTUATION_MAP = mapOf(
        "᱾" to ".",
        "᱿" to "."
    )

    private val ATOMIC_IPA = listOf(
        "p̚", "t̚", "c̚", "k̚",
        "pʼ", "tʼ", "cʼ", "kʼ",
        "pʰ", "bʰ", "tʰ", "dʰ", "ʈʰ", "ɖʰ", "cʰ", "ɟʰ", "kʰ", "ɡʰ", "ɽʰ",
        "w̃",
        "iː", "uː", "eː", "oː", "əː", "ɛː", "ɔː", "aː",
        "ĩ", "ũ", "ẽ", "õ", "ə̃", "ɛ̃", "ɔ̃", "ã",
        "ĩː", "ũː", "ẽː", "õː", "ə̃ː", "ɛ̃ː", "ɔ̃ː", "ãː",
        "ɟ", "ɲ", "ɳ", "ŋ", "ɽ", "ʈ", "ɖ", "ɡ", "ɔ", "ə", "ɛ"
    ).sortedByDescending { it.length }

    private fun normalize(text: String): String {
        var result = Normalizer.normalize(text, Normalizer.Form.NFC)
        result = result.replace(DOT + NASAL, NASAL_DOT)
        result = result.replace(NASAL + DOT, NASAL_DOT)
        result = result.replace(LONG + DOT, DOT + LONG)
        result = result.replace(LONG + NASAL, NASAL + LONG)
        result = result.replace(LONG + NASAL_DOT, NASAL_DOT + LONG)
        return result
    }

    private fun isVowelBase(ch: String): Boolean = ch in VOWEL_BASES

    private fun nextSignificant(text: String, index: Int): Int {
        var i = index
        while (i < text.length && text.substring(i, i + 1) in setOf(
                DOT, NASAL, NASAL_DOT, LONG, AHAD, ASPIRATION
            )
        ) {
            i += 1
        }
        return i
    }

    private fun isCoda(text: String, consonantEnd: Int): Boolean {
        val j = nextSignificant(text, consonantEnd)
        if (j >= text.length) return true
        val ch = text.substring(j, j + 1)
        if (ch[0].isWhitespace() || ch in listOf(",", "!", "?", ";", ":", "(", ")", "\"", "'", "“", "”", "‘", "’", ".")) {
            return true
        }
        return !isVowelBase(ch)
    }

    private data class ConsumedVowel(val ipa: String, val nextIndex: Int)
    private data class ConsumedConsonant(val ipa: String, val nextIndex: Int)

    private fun consumeVowel(text: String, start: Int): ConsumedVowel {
        var i = start
        var base = VOWEL_BASES[text.substring(i, i + 1)]!!
        i += 1

        var modifier: String? = null
        if (i < text.length && text.substring(i, i + 1) in setOf(DOT, NASAL, NASAL_DOT)) {
            modifier = text.substring(i, i + 1)
            i += 1
        }

        var longMark = false
        if (i < text.length && text.substring(i, i + 1) == LONG) {
            longMark = true
            i += 1
        }

        when (modifier) {
            DOT -> {
                if (base == "a") base = "ə"
                else if (base == "e") base = "ɛ"
                else if (base == "o") base = "ɔ"
            }
            NASAL_DOT -> {
                if (base == "a") base = "ə"
                else if (base == "e") base = "ɛ"
                else if (base == "o") base = "ɔ"
                base += "̃"
            }
            NASAL -> base += "̃"
        }

        if (longMark) base += "ː"

        return ConsumedVowel(base, i)
    }

    private fun consumeConsonant(text: String, start: Int): ConsumedConsonant {
        var i = start
        val ch = text.substring(i, i + 1)
        i += 1
        var ipa = BASIC_CONSONANTS[ch]!!

        var aspirated = false
        if (i < text.length && text.substring(i, i + 1) == ASPIRATION) {
            ipa += "ʰ"
            aspirated = true
            i += 1
        }

        if (i < text.length && text.substring(i, i + 1) == AHAD) {
            val glottalized = GLOTTALIZED[ch]
            if (glottalized != null) {
                i += 1
                return ConsumedConsonant(glottalized.first, i)
            }
            i += 1
            return ConsumedConsonant(ipa, i)
        }

        if (
            i < text.length &&
            text.substring(i, i + 1) == PHAARKAA &&
            ch in GLOTTALIZED &&
            !aspirated
        ) {
            i += 1
            return ConsumedConsonant(GLOTTALIZED[ch]!!.third, i)
        }

        if (ch in GLOTTALIZED && !aspirated && isCoda(text, i)) {
            ipa = GLOTTALIZED[ch]!!.second
        }

        if (ch == "ᱦ" && !aspirated && isCoda(text, i)) {
            ipa = "ʔ"
        }

        return ConsumedConsonant(ipa, i)
    }

    fun santaliToIpa(text: String): String {
        var normalized = normalize(text)
        val out = StringBuilder()
        var i = 0

        while (i < normalized.length) {
            val ch = normalized.substring(i, i + 1)

            if (ch[0].isWhitespace()) {
                out.append(ch)
                i += 1
                continue
            }

            if (ch in PUNCTUATION_MAP) {
                out.append(PUNCTUATION_MAP[ch]!!)
                i += 1
                continue
            }

            if (ch == PHAARKAA) {
                out.append(" ")
                i += 1
                continue
            }

            if (ch in VOWEL_BASES) {
                val consumed = consumeVowel(normalized, i)
                out.append(consumed.ipa)
                i = consumed.nextIndex
                continue
            }

            if (ch in BASIC_CONSONANTS) {
                val consumed = consumeConsonant(normalized, i)
                out.append(consumed.ipa)
                i = consumed.nextIndex
                continue
            }

            out.append(ch)
            i += 1
        }

        return out.toString()
    }

    fun santhiToIpa(text: String): String = santaliToIpa(text)

    fun tokenizeIpa(ipa: String): List<String> {
        val tokens = mutableListOf<String>()
        var i = 0

        while (i < ipa.length) {
            if (ipa[i].isWhitespace()) {
                tokens.add(ipa[i].toString())
                i += 1
                continue
            }

            var matched = false
            for (symbol in ATOMIC_IPA) {
                if (ipa.startsWith(symbol, i)) {
                    tokens.add(symbol)
                    i += symbol.length
                    matched = true
                    break
                }
            }

            if (!matched) {
                var j = i + 1
                while (j < ipa.length && isCombining(ipa[j])) {
                    j += 1
                }
                tokens.add(ipa.substring(i, j))
                i = j
            }
        }

        return tokens
    }

    fun santaliToPhonemes(text: String): List<String> =
        tokenizeIpa(santaliToIpa(text))

    private fun isCombining(ch: Char): Boolean {
        return when (Character.getType(ch)) {
            Character.NON_SPACING_MARK,
            Character.COMBINING_SPACING_MARK,
            Character.ENCLOSING_MARK -> true
            else -> false
        }
    }
}
