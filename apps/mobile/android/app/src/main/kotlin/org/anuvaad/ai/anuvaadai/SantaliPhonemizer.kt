package org.anuvaad.ai.anuvaadai

import java.text.Normalizer

/**
 * Portable Santali (Ol Chiki) -> IPA / phoneme-token converter.
 * Encodes native Ol Chiki unicode text directly into atomic IPA phoneme tokens
 * for the Santali VITS ONNX neural speech synthesis model.
 */
object SantaliPhonemizer {
    private val BASIC_CONSONANTS = mapOf(
        "\u1c6f" to "p",
        "\u1c75" to "b",
        "\u1c5b" to "t",
        "\u1c6b" to "d",
        "\u1c6a" to "c",
        "\u1c70" to "\u0256",
        "\u1c74" to "\u0288",
        "\u1c61" to "\u025f",
        "\u1c60" to "k",
        "\u1c5c" to "\u0261",
        "\u1c65" to "s",
        "\u1c66" to "h",
        "\u1c62" to "m",
        "\u1c71" to "n",
        "\u1c67" to "\u0272",
        "\u1c6c" to "\u0273",
        "\u1c5d" to "\u014b",
        "\u1c63" to "w",
        "\u1c76" to "w\u0303",
        "\u1c68" to "r",
        "\u1c72" to "\u027d",
        "\u1c5e" to "l",
        "\u1c6d" to "j"
    )

    private val VOWEL_BASES = mapOf(
        "\u1c64" to "i",
        "\u1c69" to "u",
        "\u1c6e" to "e",
        "\u1c73" to "o",
        "\u1c5a" to "\u0254",
        "\u1c5f" to "a"
    )

    private const val NASAL = "\u1c78"
    private const val DOT = "\u1c79"
    private const val NASAL_DOT = "\u1c7a"
    private const val LONG = "\u1c7b"
    private const val PHAARKAA = "\u1c7c"
    private const val AHAD = "\u1c7d"
    private const val ASPIRATION = "\u1c77"

    private val GLOTTALIZED = mapOf(
        "\u1c75" to Triple("b", "p\u031a", "p\u02bc"),
        "\u1c61" to Triple("\u025f", "c\u031a", "c\u02bc"),
        "\u1c6b" to Triple("d", "t\u031a", "t\u02bc"),
        "\u1c5c" to Triple("\u0261", "k\u031a", "k\u02bc")
    )

    private val PUNCTUATION_MAP = mapOf(
        "\u1c7e" to ".",
        "\u1c7f" to "."
    )

    private val ATOMIC_IPA = listOf(
        "p\u031a", "t\u031a", "c\u031a", "k\u031a",
        "p\u02bc", "t\u02bc", "c\u02bc", "k\u02bc",
        "p\u02b0", "b\u02b0", "t\u02b0", "d\u02b0", "\u0288\u02b0", "\u0256\u02b0", "c\u02b0", "\u025f\u02b0", "k\u02b0", "\u0261\u02b0", "\u027d\u02b0",
        "w\u0303",
        "i\u02d0", "u\u02d0", "e\u02d0", "o\u02d0", "\u0259\u02d0", "\u025b\u02d0", "\u0254\u02d0", "a\u02d0",
        "\u0129", "\u0169", "\u1ebd", "\u00f5", "\u0259\u0303", "\u025b\u0303", "\u0254\u0303", "\u00e3",
        "\u0129\u02d0", "\u0169\u02d0", "\u1ebd\u02d0", "\u00f5\u02d0", "\u0259\u0303\u02d0", "\u025b\u0303\u02d0", "\u0254\u0303\u02d0", "\u00e3\u02d0",
        "\u025f", "\u0272", "\u0273", "\u014b", "\u027d", "\u0288", "\u0256", "\u0261", "\u0254", "\u0259", "\u025b"
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
        if (ch[0].isWhitespace() || ch in listOf(",", "!", "?", ";", ":", "(", ")", "\"", "'", "\u201c", "\u201d", "\u2018", "\u2019", ".")) {
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
                if (base == "a") base = "\u0259"
                else if (base == "e") base = "\u025b"
                else if (base == "o") base = "\u0254"
            }
            NASAL_DOT -> {
                if (base == "a") base = "\u0259"
                else if (base == "e") base = "\u025b"
                else if (base == "o") base = "\u0254"
                base += "\u0303"
            }
            NASAL -> base += "\u0303"
        }

        if (longMark) base += "\u02d0"

        return ConsumedVowel(base, i)
    }

    private fun consumeConsonant(text: String, start: Int): ConsumedConsonant {
        var i = start
        val ch = text.substring(i, i + 1)
        i += 1
        var ipa = BASIC_CONSONANTS[ch]!!

        var aspirated = false
        if (i < text.length && text.substring(i, i + 1) == ASPIRATION) {
            ipa += "\u02b0"
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

        if (ch == "\u1c66" && !aspirated && isCoda(text, i)) {
            ipa = "\u0294"
        }

        return ConsumedConsonant(ipa, i)
    }

    fun santaliToIpa(text: String): String {
        val normalized = normalize(text)
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
            Character.NON_SPACING_MARK.toInt(),
            Character.COMBINING_SPACING_MARK.toInt(),
            Character.ENCLOSING_MARK.toInt() -> true
            else -> false
        }
    }
}
