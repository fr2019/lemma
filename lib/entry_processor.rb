#
#  lib/entry_processor.rb
#  Processes dictionary entries from JSONL data
#
#  Created by Francisco Riordan on 4/22/25.
#

require 'json'

class EntryProcessor
  def initialize(generator)
    @generator = generator
    @entries = generator.entries
    @lemma_inflections = generator.lemma_inflections
  end

  def process
    puts "Processing entries..."

    # First pass: count total entries if we need to limit
    total_lines = 0
    if @generator.limit_percent
      File.open("greek_data_#{@generator.source_lang}_#{@generator.download_date}.jsonl", "r:UTF-8:UTF-8", invalid: :replace, undef: :replace) do |file|
        file.each_line do |line|
          next if line.strip.empty? rescue next
          begin
            entry = JSON.parse(line)
            next unless is_greek_entry?(entry)
            next unless entry["word"]
            total_lines += 1
          rescue JSON::ParserError
            next
          end
        end
      end

      puts "Found #{total_lines} Greek entries total"
    end

    line_count = 0
    error_count = 0
    processed_count = 0
    max_entries = @generator.limit_percent ? (total_lines * @generator.limit_percent / 100.0).ceil : nil

    File.open("greek_data_#{@generator.source_lang}_#{@generator.download_date}.jsonl", "r:UTF-8:UTF-8", invalid: :replace, undef: :replace) do |file|
      file.each_line do |line|
        line_count += 1

        # Handle encoding issues
        begin
          line = line.strip
        rescue => e
          error_count += 1
          if error_count <= 10
            puts "Error on line #{line_count}: #{e.message}"
          end
          next
        end

        next if line.empty?

        begin
          entry = JSON.parse(line)
        rescue JSON::ParserError => e
          error_count += 1
          if error_count <= 10
            puts "JSON parse error on line #{line_count}: #{e.message}"
          end
          next
        rescue => e
          error_count += 1
          if error_count <= 10
            puts "Unexpected error on line #{line_count}: #{e.class} - #{e.message}"
          end
          next
        end

        # Try to extract the extraction date from first entry's meta field
        if @generator.extraction_date.nil? && entry["meta"]
          if entry["meta"]["extracted"]
            @generator.set_extraction_date(entry["meta"]["extracted"])
          elsif entry["meta"]["date"]
            @generator.set_extraction_date(entry["meta"]["date"])
          end
        end

        # Only process Greek entries
        next unless is_greek_entry?(entry)

        word = entry["word"]
        next unless word

        # Skip if word doesn't contain Greek characters
        next unless contains_greek?(word)

        # Skip if word contains non-Greek scripts (except Latin for loanwords)
        next if contains_non_greek_script?(word)

        # Check if we've reached the limit
        if max_entries && processed_count >= max_entries
          puts "Reached limit of #{max_entries} entries (#{@generator.limit_percent}%)"
          break
        end

        processed_count += 1

        pos = entry["pos"] || "unknown"

        # Skip non-selectable word types
        next if should_skip_pos?(pos)

        # Also skip entries that look like prefixes/suffixes based on the word itself
        next if word.start_with?('-') || word.end_with?('-')

        # Skip very short words that are likely particles or fragments
        next if word.length == 1 && !["ω", "ο", "α", "η"].include?(word.downcase)

        # Process the entry
        process_single_entry(entry, word, pos)
      end
    end

    puts "Processed #{line_count} lines with #{error_count} errors"
    puts "Found #{@entries.size} unique headwords (processed #{processed_count} entries)"
    puts "Note: Prefixes, suffixes, and other non-selectable word types were excluded"

    # Count and merge inflections
    merge_inflections

    # Report final statistics
    report_statistics
  end

  private

  def is_greek_entry?(entry)
    entry["lang"] == "Greek" || entry["lang"] == "Ελληνικά" || entry["lang_code"] == "el"
  end

  def contains_greek?(word)
    # Check if word contains at least one Greek character
    word.match?(/\p{Greek}/)
  end

  def contains_non_greek_script?(word)
    # Allow only Greek letters and common punctuation
    # Reject if it contains Latin letters (except for specific single-letter words)
    # or other non-Greek scripts

    # Special cases for accepted Latin-only words (like single letters used as words)
    return false if ["a", "A", "b", "B"].include?(word)

    # Check if word contains any Latin letters (except in the special cases above)
    return true if word.match?(/[a-zA-Z]/)

    # Check if word contains other non-Greek scripts
    word.match?(/[^\p{Greek}\p{Nd}\s\-',.:;!?()]/)
  end

  def should_skip_pos?(pos)
    skip_pos = [
      "prefix", "suffix", "infix", "circumfix",
      "combining form", "combining_form",
      "interfix", "affix",
      "preverb", "postposition",
      "enclitic", "proclitic", "clitic",
      "particle", # Often not standalone
      "diacritical mark", "diacritical_mark",
      "punctuation mark", "punctuation_mark",
      "symbol",
      "letter", # Individual letters
      "character",
      "abbreviation", # Usually not selectable as is
      "initialism",
      "contraction" # Often part of other words
    ]

    skip_pos.any? { |skip| pos.downcase.include?(skip) }
  end

  def process_single_entry(entry, word, pos)
    # Build definition from senses
    definitions = []
    lemma_redirect = nil

    if entry["senses"]
      entry["senses"].each_with_index do |sense, idx|
        # Check if this is just an inflection of another word
        if sense["form_of"]
          form_of_info = sense["form_of"][0] if sense["form_of"].is_a?(Array)
          if form_of_info && form_of_info["word"]
            lemma_redirect = form_of_info["word"]
            next
          end
        end

        # Extract glosses (definitions)
        definition = extract_definition_from_sense(sense)
        definitions << definition unless definition.strip.empty?
      end
    end

    # If this word is just an inflection of another word, add it to that word's inflections
    if lemma_redirect
      @lemma_inflections[lemma_redirect] ||= []
      @lemma_inflections[lemma_redirect] << word
      return
    end

    # Store each definition separately
    definitions = ["No definition available"] if definitions.empty?

    # Handle forms and collect inflections
    inflections = collect_inflections(entry, word)

    # Store entry with inflections
    @entries[word] ||= []

    # Check if we already have an entry with the same POS
    existing_entry = @entries[word].find { |e| e[:pos] == pos }

    if existing_entry
      # Merge definitions and inflections
      existing_entry[:definitions] += definitions
      existing_entry[:definitions].uniq!
      existing_entry[:inflections] += inflections
      existing_entry[:inflections].uniq!
      existing_entry[:etymology] ||= entry["etymology_text"]
    else
      @entries[word] << {
        pos: pos,
        definitions: definitions,
        etymology: entry["etymology_text"],
        inflections: inflections.uniq
      }
    end
  end

  def extract_definition_from_sense(sense)
    definition = ""

    if sense["glosses"]
      glosses = sense["glosses"]
      definition = glosses.is_a?(Array) ? glosses.join("; ") : glosses.to_s

      # Add raw_tags if present
      if sense["raw_tags"] && sense["raw_tags"].is_a?(Array)
        tags = sense["raw_tags"].join(", ")
        definition = "[#{tags}] #{definition}"
      end
    elsif sense["raw_glosses"]
      raw_glosses = sense["raw_glosses"]
      definition = raw_glosses.is_a?(Array) ? raw_glosses.join("; ") : raw_glosses.to_s
    end

    definition
  end

  def collect_inflections(entry, word)
    inflections = []

    if entry["forms"]
      entry["forms"].each do |form|
        if form.is_a?(Hash)
          form_word = form["form"]
          next if form_word && form_word.match(/[a-zA-Z]/)
          next if form["tags"] && form["tags"].include?("romanization")
          next if form_word && (form_word.start_with?('-') || form_word.end_with?('-'))
          inflections << form_word if form_word && form_word != word
        elsif form.is_a?(String) && form != word && !form.match(/[a-zA-Z]/)
          next if form.start_with?('-') || form.end_with?('-')
          inflections << form
        end
      end
    end

    if entry["related"]
      entry["related"].each do |related|
        inflections << related["word"] if related["word"] && related["word"] != word
      end
    end

    inflections
  end

  def merge_inflections
    if @lemma_inflections
      @lemma_inflections.each do |lemma, inflected_forms|
        if @entries[lemma]
          @entries[lemma].each do |entry|
            entry[:inflections] ||= []
            filtered_forms = inflected_forms.reject { |f| f.start_with?('-') || f.end_with?('-') }
            entry[:inflections] += filtered_forms
            entry[:inflections].uniq!
          end
        end
      end
      puts "Added #{@lemma_inflections.size} additional inflection mappings from form_of entries"
    end
  end

  def report_statistics
    # Count total inflections
    total_inflections = 0
    @entries.each do |word, entries|
      entries.each do |entry|
        total_inflections += (entry[:inflections] || []).size
      end
    end
    puts "Total inflections: #{total_inflections}"
    puts "Wiktionary extraction date found: #{@generator.extraction_date}" if @generator.extraction_date
  end
end
