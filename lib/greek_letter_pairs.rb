#
#  lib/greek_letter_pairs.rb
#  Shared Greek letter group definitions
#
#  Created by Francisco Riordan on 4/22/25.
#

module GreekLetterPairs
  LETTER_PAIRS = [
    ['Α', 'Β', 'Γ', 'Δ', 'Ε'],
    ['Ζ', 'Η', 'Θ', 'Ι', 'Κ'],
    ['Λ', 'Μ', 'Ν', 'Ξ', 'Ο'],
    ['Π', 'Ρ', 'Σ', 'Τ', 'Υ'],
    ['Φ', 'Χ', 'Ψ', 'Ω']
  ].freeze

  def self.get_letter_pairs
    LETTER_PAIRS
  end

  def self.total_parts
    LETTER_PAIRS.length
  end

  def self.get_first_letter(word)
    # Get the first letter of a word, normalized to uppercase
    return nil unless word && !word.empty?

    first_char = word[0].upcase

    # Handle special cases for Greek letters
    accent_map = {
      'Ά' => 'Α', 'Έ' => 'Ε', 'Ή' => 'Η', 'Ί' => 'Ι',
      'Ό' => 'Ο', 'Ύ' => 'Υ', 'Ώ' => 'Ω'
    }

    accent_map[first_char] || first_char
  end

  def self.word_belongs_to_part(word, part_num)
    first_letter = get_first_letter(word)
    return false unless first_letter

    return false if part_num < 1 || part_num > LETTER_PAIRS.length

    group = LETTER_PAIRS[part_num - 1]
    group.include?(first_letter)
  end
end
