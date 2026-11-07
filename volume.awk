# Shakespeare volume test: portable POSIX AWK, no extensions.
# Run with LC_ALL=C: length($0)+1 counts bytes including each line's LF.
# In a multibyte-aware UTF-8 interpreter it counts Unicode characters instead.
# The inputs always end in LF. Whitespace words = sum NF (like wc -w in C).
# Frequency words: maximal ASCII-letter/apostrophe sequences, lowercased;
# strip leading/trailing ASCII apostrophes, discard empty results.
# Curly apostrophes and non-ASCII letters are separators, deliberately.
# Ties: ASCII alphabetical. Keep sorted bounded lists by insertion, not a
# quadratic sort of the entire vocabulary. Cost O(tokens + 10*unique words).
{
    characters += length($0) + 1
    words += NF
    lines++
    count = split(tolower($0), parts, /[^a-z']+/)
    for (i = 1; i <= count; i++) {
        word = parts[i]
        sub(/^'+/, "", word)
        sub(/'+$/, "", word)
        if (word != "") frequency[word]++
    }
}
END {
    minimum = 0
    for (word in frequency) {
        unique++
        f = frequency[word]
        if (minimum == 0 || f < minimum) { minimum = f; minimum_words = 1 }
        else if (f == minimum) minimum_words++
        # Insert in descending-frequency / ascending-alphabetical order.
        if (ntop < 10 || f > frequency[top[ntop]] ||
            (f == frequency[top[ntop]] && word < top[ntop])) {
            p = ntop + 1
            if (p > 10) p = 10
            while (p > 1 && (f > frequency[top[p-1]] ||
                   (f == frequency[top[p-1]] && word < top[p-1]))) {
                top[p] = top[p-1]; p--
            }
            top[p] = word
            if (ntop < 10) ntop++
        }
        # Same insertion with frequency ascending for the least common.
        if (nbottom < 10 || f < frequency[bottom[nbottom]] ||
            (f == frequency[bottom[nbottom]] && word < bottom[nbottom])) {
            p = nbottom + 1
            if (p > 10) p = 10
            while (p > 1 && (f < frequency[bottom[p-1]] ||
                   (f == frequency[bottom[p-1]] && word < bottom[p-1]))) {
                bottom[p] = bottom[p-1]; p--
            }
            bottom[p] = word
            if (nbottom < 10) nbottom++
        }
    }
    printf "Characters: %.0f\nWords: %.0f\nLines: %.0f\nUnique words: %d\n", characters, words, lines, unique
    print "Most common words:"
    for (i = 1; i <= ntop; i++) printf "%s %d\n", top[i], frequency[top[i]]
    print "Least common words:"
    for (i = 1; i <= nbottom; i++) printf "%s %d\n", bottom[i], frequency[bottom[i]]
    printf "Lowest frequency: %d\nWords at lowest frequency: %d\n", minimum, minimum_words
    if (minimum_words > 10) {
        if (minimum == 1) printf "%d words occur only once; first 10 alphabetically shown\n", minimum_words
        else printf "%d words occur %d times; first 10 alphabetically shown\n", minimum_words, minimum
    }
}
