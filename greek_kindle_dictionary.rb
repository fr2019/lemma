#!/usr/bin/env ruby
#
#  greek_kindle_dictionary.rb
#  Lemma - Greek Kindle Dictionary Generator
#
#  Created by Francisco Riordan on 4/22/25.
#

require 'net/http'
require 'json'
require 'fileutils'
require 'time'
require 'optparse'

class GreekKindleDictionary
  KAIKKI_URLS = {
    'en' => "https://kaikki.org/dictionary/Greek/kaikki.org-dictionary-Greek.jsonl",
    'el' => "https://kaikki.org/elwiktionary/Greek/kaikki.org-dictionary-Greek.jsonl"
  }

  # Local fallback files
  LOCAL_FALLBACK_FILES = {
    'en' => 'greek_data_en_20250716.jsonl',
    'el' => 'greek_data_el_20250717.jsonl'
  }

  def initialize(source_lang = 'en')
    @source_lang = source_lang
    @entries = {}
    @lemma_inflections = {}
    @extraction_date = nil
    @download_date = Time.now.strftime("%Y%m%d")
    @output_dir = "lemma_greek_#{@source_lang}_#{@download_date}"

    puts "Initialized with:"
    puts "  Source: #{source_lang == 'en' ? 'English' : 'Greek'} Wiktionary"
    puts "  Download date: #{@download_date}"
  end

  def generate
    puts "Lemma - Greek Kindle Dictionary Generator"
    puts "Download date: #{@download_date}"

    if @download_date.nil? || @download_date.empty?
      puts "Warning: Download date was not set properly, regenerating..."
      @download_date = Time.now.strftime("%Y%m%d")
      @output_dir = "lemma_greek_#{@download_date}"
    end

    download_data
    process_entries
    create_output_files
    generate_mobi

    puts "\nDictionary generation complete!"
    puts "Files created in #{@output_dir}/"
    puts "Wiktionary extraction date: #{@extraction_date}" if @extraction_date
  end

  private

  def download_data
    puts "Downloading Greek data from #{@source_lang == 'en' ? 'English' : 'Greek'} Wiktionary via Kaikki..."

    # Ensure we have a valid download date
    if @download_date.nil? || @download_date.empty?
      @download_date = Time.now.strftime("%Y%m%d")
    end

    # Primary URL and target filename
    primary_url = KAIKKI_URLS[@source_lang]
    target_filename = "greek_data_#{@source_lang}_#{@download_date}.jsonl"

    # Try primary URL first
    success = download_from_url(primary_url, target_filename)

    # If primary fails, try local fallback file
    unless success
      local_fallback = LOCAL_FALLBACK_FILES[@source_lang]

      if File.exist?(local_fallback)
        puts "Primary download failed. Using local fallback file: #{local_fallback}"

        # Extract date from fallback filename
        fallback_date = local_fallback.match(/greek_data_#{@source_lang}_(\d{8})\.jsonl/)[1] rescue nil

        if fallback_date
          @download_date = fallback_date
          @output_dir = "lemma_greek_#{@source_lang}_#{@download_date}"
          puts "Using fallback date: #{fallback_date}"
        else
          puts "Warning: Could not extract date from fallback filename"
        end
      else
        # If local file doesn't exist, try GitHub fallback
        puts "Primary download failed and local fallback not found. Attempting GitHub fallback..."

        github_urls = {
          'en' => 'https://raw.githubusercontent.com/fr2019/lemma/main/greek_data_en_20250716.jsonl',
          'el' => 'https://raw.githubusercontent.com/fr2019/lemma/main/greek_data_el_20250717.jsonl'
        }

        fallback_date = github_urls[@source_lang].match(/greek_data_#{@source_lang}_(\d{8})\.jsonl/)[1] rescue nil
        fallback_filename = "greek_data_#{@source_lang}_#{fallback_date}.jsonl"

        success = download_from_url(github_urls[@source_lang], fallback_filename)

        if success
          puts "GitHub fallback download successful. Using fallback date: #{fallback_date}"
          @download_date = fallback_date
          @output_dir = "lemma_greek_#{@source_lang}_#{@download_date}"
        else
          puts "Error: All download attempts failed."
          puts "Try downloading manually from: #{github_urls[@source_lang]}"
          puts "Save as: #{fallback_filename}"
          exit 1
        end
      end
    end
  end

  # Helper method to handle downloading from a given URL
  def download_from_url(url, filename)
    uri = URI(url)
    Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
      request = Net::HTTP::Get.new(uri)
      request['User-Agent'] = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36'

      response = http.request(request)

      case response
      when Net::HTTPSuccess
        File.open(filename, "w") do |file|
          file.write(response.body)
        end
        puts "Downloaded #{response.body.lines.count} entries to #{filename}"
        return true
      else
        puts "Error downloading from #{url}: #{response.code} #{response.message}"
        return false
      end
    end
  rescue StandardError => e
    puts "Exception during download from #{url}: #{e.message}"
    return false
  end

  def process_entries
    puts "Processing entries..."

    # Ensure we have a valid download date
    if @download_date.nil? || @download_date.empty?
      @download_date = Time.now.strftime("%Y%m%d")
    end

    line_count = 0
    error_count = 0

    File.foreach("greek_data_#{@source_lang}_#{@download_date}.jsonl") do |line|
      line_count += 1
      next if line.strip.empty?

      begin
        entry = JSON.parse(line)
      rescue JSON::ParserError => e
        error_count += 1
        puts "Error parsing line #{line_count}: #{e.message}" if error_count < 10
        next
      end

      # Try to extract the extraction date from first entry's meta field
      if @extraction_date.nil? && entry["meta"]
        if entry["meta"]["extracted"]
          @extraction_date = entry["meta"]["extracted"]
        elsif entry["meta"]["date"]
          @extraction_date = entry["meta"]["date"]
        end
      end

      # Only process Greek entries
      next unless entry["lang"] == "Greek" || entry["lang"] == "Ελληνικά" || entry["lang_code"] == "el"

      word = entry["word"]
      next unless word

      pos = entry["pos"] || "unknown"

      # Build definition from senses - handle both English and Greek definitions
      definitions = []
      lemma_redirect = nil

      if entry["senses"]
        entry["senses"].each_with_index do |sense, idx|
          # Check if this is just an inflection of another word
          if sense["form_of"]
            # This is an inflected form pointing to a lemma
            form_of_info = sense["form_of"][0] if sense["form_of"].is_a?(Array)
            if form_of_info && form_of_info["word"]
              lemma_redirect = form_of_info["word"]
              # Skip creating a separate entry for this inflection
              next
            end
          end

          # Extract glosses (definitions)
          if sense["glosses"]
            # For Greek entries from Greek wiktionary, glosses are in Greek
            # Join multiple glosses with semicolon for consistency
            glosses = sense["glosses"]
            if glosses.is_a?(Array)
              definition = glosses.join("; ")
            else
              definition = glosses.to_s
            end

            # Add raw_tags if present (like "γλωσσολογία", "γραμματική", etc.)
            if sense["raw_tags"] && sense["raw_tags"].is_a?(Array)
              tags = sense["raw_tags"].join(", ")
              definition = "[#{tags}] #{definition}"
            end

            definitions << definition unless definition.strip.empty?
          elsif sense["raw_glosses"]
            # Fallback to raw glosses if available
            raw_glosses = sense["raw_glosses"]
            if raw_glosses.is_a?(Array)
              definition = raw_glosses.join("; ")
            else
              definition = raw_glosses.to_s
            end
            definitions << definition unless definition.strip.empty?
          end
        end
      end

      # If this word is just an inflection of another word, add it to that word's inflections
      if lemma_redirect
        # Add this word as an inflection of the lemma
        @lemma_inflections ||= {}
        @lemma_inflections[lemma_redirect] ||= []
        @lemma_inflections[lemma_redirect] << word
        next # Skip creating a separate entry
      end

      # Store each definition separately instead of joining them
      if definitions.empty?
        definitions = ["No definition available"]
      end

      # Handle forms and collect inflections
      inflections = []
      if entry["forms"]
        entry["forms"].each do |form|
          # Handle different form structures
          if form.is_a?(Hash)
            form_word = form["form"]
            # Skip if it's a romanization (contains Latin characters)
            next if form_word && form_word.match(/[a-zA-Z]/)
            # Skip if it has 'tags' containing 'romanization'
            next if form["tags"] && form["tags"].include?("romanization")
            # Add if it's different from the main word
            if form_word && form_word != word
              inflections << form_word
            end
          elsif form.is_a?(String) && form != word && !form.match(/[a-zA-Z]/)
            # Handle simple string forms
            inflections << form
          end
        end
      end

      # Also collect related words if they might be forms
      # Note: "related" words have their own "roman" field for transliteration
      # which we simply ignore - we only want the "word" field
      if entry["related"]
        entry["related"].each do |related|
          if related["word"] && related["word"] != word
            inflections << related["word"]
          end
        end
      end

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
        # Keep the first etymology if we don't have one
        existing_entry[:etymology] ||= entry["etymology_text"]
      else
        @entries[word] << {
          pos: pos,
          definitions: definitions,  # Now an array instead of a single string
          etymology: entry["etymology_text"],
          inflections: inflections.uniq
        }
      end
    end

    puts "Processed #{line_count} lines with #{error_count} errors"
    puts "Found #{@entries.size} headwords"

    # Count total inflections
    total_inflections = 0
    @entries.each do |word, entries|
      entries.each do |entry|
        total_inflections += (entry[:inflections] || []).size
      end
    end
    puts "Found #{total_inflections} inflections from forms"

    puts "Wiktionary extraction date found: #{@extraction_date}" if @extraction_date

    # Merge inflections from lemma_inflections into the main entries
    if @lemma_inflections
      @lemma_inflections.each do |lemma, inflected_forms|
        if @entries[lemma]
          @entries[lemma].each do |entry|
            entry[:inflections] ||= []
            entry[:inflections] += inflected_forms
            entry[:inflections].uniq!
          end
        end
      end
      puts "Added #{@lemma_inflections.size} additional inflection mappings from form_of entries"
    end

    # Final count
    final_total_inflections = 0
    @entries.each do |word, entries|
      entries.each do |entry|
        final_total_inflections += (entry[:inflections] || []).size
      end
    end
    puts "Total inflections after merging: #{final_total_inflections}"
  end

  def create_output_files
    if @output_dir.nil? || @output_dir.empty?
      puts "Error: Output directory is nil or empty!"
      @output_dir = "lemma_greek_#{Time.now.strftime('%Y%m%d')}"
      puts "Using fallback directory: #{@output_dir}"
    end

    # Clean up existing directory if it exists
    if Dir.exist?(@output_dir)
      puts "Removing existing directory: #{@output_dir}"
      FileUtils.rm_rf(@output_dir)
    end

    FileUtils.mkdir_p(@output_dir)

    create_content_html
    create_cover_html
    create_copyright_html
    create_usage_html
    create_opf_file
  end

  def create_content_html
    puts "Creating content.html..."

    content = <<~HTML
      <html xmlns:math="http://exslt.org/math" xmlns:svg="http://www.w3.org/2000/svg"
            xmlns:tl="https://kindlegen.s3.amazonaws.com/AmazonKindlePublishingGuidelines.pdf"
            xmlns:saxon="http://saxon.sf.net/" xmlns:xs="http://www.w3.org/2001/XMLSchema"
            xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
            xmlns:cx="https://kindlegen.s3.amazonaws.com/AmazonKindlePublishingGuidelines.pdf"
            xmlns:dc="http://purl.org/dc/elements/1.1/"
            xmlns:mbp="https://kindlegen.s3.amazonaws.com/AmazonKindlePublishingGuidelines.pdf"
            xmlns:mmc="https://kindlegen.s3.amazonaws.com/AmazonKindlePublishingGuidelines.pdf"
            xmlns:idx="https://kindlegen.s3.amazonaws.com/AmazonKindlePublishingGuidelines.pdf">
        <head>
          <meta http-equiv="Content-Type" content="text/html; charset=utf-8">
          <style>
            h5 {
                font-size: 1em;
                margin: 0;
            }
            dt {
                font-weight: bold;
            }
            dd {
                margin: 0;
                padding: 0 0 0.5em 0;
                display: block
            }
            p {
                margin: 0.2em 0;
            }
            b {
                font-weight: bold;
            }
            i {
                font-style: italic;
            }
            .pos {
                font-style: italic;
                color: #666;
            }
            .etymology {
                font-size: 0.9em;
                color: #444;
                margin-top: 0.3em;
            }
            .redirect {
                font-style: italic;
            }
            hr {
                margin: 5px 0;
                border: none;
                border-top: 1px solid #ccc;
            }
          </style>
        </head>
        <body>
          <mbp:frameset>
    HTML

    # Sort entries alphabetically
    sorted_entries = @entries.sort_by { |word, _| word }

    # Add main entries only - no separate redirect entries needed
    sorted_entries.each do |word, entries|
      content << create_entry(word, entries)
    end

    content << <<~HTML
          </mbp:frameset>
        </body>
      </html>
    HTML

    File.write("#{@output_dir}/content.html", content)
  end

  def create_entry(word, entries)
    # Combine all inflections from all entries for this word
    all_inflections = entries.flat_map { |e| e[:inflections] || [] }.uniq

    # Add capitalized and uppercase versions of the word and its inflections
    word_variations = [word.capitalize, word.upcase].select { |v| v != word }
    inflection_variations = all_inflections.flat_map { |i| [i.capitalize, i.upcase] }.uniq - all_inflections - [word]
    all_variations = (all_inflections + word_variations + inflection_variations).uniq

    entry_html = <<~HTML
      <idx:entry name="default" scriptable="yes" spell="yes">
        <idx:short>
          <idx:orth value="#{escape_html(word)}"><b>#{escape_html(word)}</b>
    HTML

    # Add inflections and variations if any exist
    if all_variations.any?
      entry_html << "            <idx:infl>\n"
      all_variations.each do |variation|
        entry_html << "              <idx:iform value=\"#{escape_html(variation)}\" exact=\"yes\" />\n"
      end
      entry_html << "            </idx:infl>\n"
    end

    entry_html << "          </idx:orth>\n"
    entry_html << "        </idx:short>\n"

    # Group entries by part of speech with better formatting
    entries.each_with_index do |entry, idx|
      # Format part of speech nicely
      pos_display = entry[:pos] || "unknown"
      # Common Greek POS mappings for better display
      pos_map = {
        "noun" => "ουσιαστικό",
        "verb" => "ρήμα",
        "adj" => "επίθετο",
        "adjective" => "επίθετο",
        "adv" => "επίρρημα",
        "adverb" => "επίρρημα",
        "num" => "αριθμητικό",
        "numeral" => "αριθμητικό",
        "name" => "κύριο όνομα",
        "proper noun" => "κύριο όνομα",
        "article" => "άρθρο"
      }

      # Use Greek term if available in mapping, otherwise use original
      if @source_lang == 'el' && pos_map[pos_display.downcase]
        pos_display = pos_map[pos_display.downcase]
      end

      entry_html << "        <p><i>#{escape_html(pos_display)}</i></p>\n"

      # Add each definition on its own line with numbering
      if entry[:definitions].size > 1
        entry[:definitions].each_with_index do |definition, def_idx|
          entry_html << "        <p style=\"margin-left: 20px;\">#{def_idx + 1}. #{escape_html(definition)}</p>\n"
        end
      else
        # Single definition without numbering
        entry[:definitions].each do |definition|
          entry_html << "        <p style=\"margin-left: 20px;\">#{escape_html(definition)}</p>\n"
        end
      end

      if entry[:etymology] && !entry[:etymology].strip.empty?
        entry_html << "        <p class='etymology'>[Ετυμολογία: #{escape_html(entry[:etymology])}]</p>\n"
      end

      # Add separator between multiple POS entries
      if entries.size > 1 && idx < entries.size - 1
        entry_html << "        <hr style=\"margin: 10px 0 10px 0; border: none; border-top: 1px dotted #ccc;\" />\n"
      end
    end

    entry_html << <<~HTML
      </idx:entry>
      <hr/>
    HTML

    entry_html
  end

  def create_cover_html
    source_desc = @source_lang == 'en' ? 'English Wiktionary' : 'Greek Wiktionary (Monolingual)'
    date_info = @extraction_date ? "Wiktionary data from: #{@extraction_date}" : "Downloaded: #{@download_date}"

    File.write("#{@output_dir}/cover.html", <<~HTML)
      <html>
        <head>
          <meta content="text/html; charset=utf-8" http-equiv="content-type">
        </head>
        <body>
          <h1>Lemma Greek Dictionary</h1>
          <h3>From #{source_desc}</h3>
          <h3>A Lemma Project</h3>
          <p>#{date_info}</p>
        </body>
      </html>
    HTML
  end

  def create_copyright_html
    File.write("#{@output_dir}/copyright.html", <<~HTML)
      <html>
        <head>
          <meta content="text/html; charset=utf-8" http-equiv="content-type">
        </head>
        <body>
          <h2>Copyright Notice</h2>
          <p>This dictionary is created from Wiktionary data processed by Kaikki.</p>
          <p>Wiktionary content is available under the Creative Commons Attribution-ShareAlike License.</p>
          <p>Dictionary compilation by Lemma, #{Time.now.year}</p>
          <p>Wiktionary data extracted: #{@extraction_date || 'Unknown'}</p>
          <p>Dictionary created: #{@download_date}</p>
        </body>
      </html>
    HTML
  end

  def create_usage_html
    dict_type = @source_lang == 'en' ? 'Greek-English' : 'Greek-Greek (monolingual)'

    File.write("#{@output_dir}/usage.html", <<~HTML)
      <html>
        <head>
          <meta content="text/html; charset=utf-8" http-equiv="content-type">
        </head>
        <body>
          <h2>How to Use Lemma Greek Dictionary</h2>
          <p>This is a #{dict_type} dictionary with Modern Greek words from #{@source_lang == 'en' ? 'English' : 'Greek'} Wiktionary.</p>
          <h3>Features:</h3>
          <ul>
            <li>Look up any Greek word while reading</li>
            <li>Inflected forms automatically redirect to their lemma</li>
            <li>Includes part of speech and etymology information where available</li>
          </ul>
          <h3>To set as default Greek dictionary:</h3>
          <ol>
            <li>Look up any Greek word in your book</li>
            <li>Tap the dictionary name in the popup</li>
            <li>Select "Lemma Greek Dictionary"</li>
          </ol>
        </body>
      </html>
    HTML
  end

  def create_opf_file
    source_name = @source_lang == 'en' ? 'en-el' : 'el-el'
    title_with_date = "Lemma Greek Dictionary #{source_name.upcase} (#{@extraction_date || @download_date})"
    out_lang = @source_lang == 'en' ? 'en' : 'el'

    File.write("#{@output_dir}/lemma_greek_#{@source_lang}_#{@download_date}.opf", <<~XML)
      <?xml version="1.0"?>
      <package version="2.0" xmlns="http://www.idpf.org/2007/opf" unique-identifier="BookId">
        <metadata>
          <dc:title>#{title_with_date}</dc:title>
          <dc:creator opf:role="aut">Lemma</dc:creator>
          <dc:language>el</dc:language>
          <dc:date>#{@download_date}</dc:date>
          <meta name="wiktionary-extraction-date" content="#{@extraction_date || 'Unknown'}" />
          <x-metadata>
            <DictionaryInLanguage>el</DictionaryInLanguage>
            <DictionaryOutLanguage>#{out_lang}</DictionaryOutLanguage>
            <DefaultLookupIndex>default</DefaultLookupIndex>
          </x-metadata>
        </metadata>
        <manifest>
          <item id="cover"
                href="cover.html"
                media-type="application/xhtml+xml" />
          <item id="usage"
                href="usage.html"
                media-type="application/xhtml+xml" />
          <item id="copyright"
                href="copyright.html"
                media-type="application/xhtml+xml" />
          <item id="content"
                href="content.html"
                media-type="application/xhtml+xml" />
        </manifest>
        <spine>
          <itemref idref="cover" />
          <itemref idref="usage" />
          <itemref idref="copyright"/>
          <itemref idref="content"/>
        </spine>
        <guide>
          <reference type="index" title="IndexName" href="content.html"/>
        </guide>
      </package>
    XML
  end

  def generate_mobi
    puts "\nGenerating MOBI file with Kindle Previewer..."

    # Try multiple possible Kindle Previewer paths
    kindle_previewer_paths = [
      "/Applications/Kindle Previewer 3.app/Contents/lib/fc/bin/kindlepreviewer",
      "/Applications/Kindle Previewer.app/Contents/lib/fc/bin/kindlepreviewer",
      "#{ENV['HOME']}/Applications/Kindle Previewer 3.app/Contents/lib/fc/bin/kindlepreviewer",
      "kindlepreviewer"
    ]

    kindle_previewer = kindle_previewer_paths.find { |path| File.exist?(path) || system("which #{path} > /dev/null 2>&1") }

    if kindle_previewer
      Dir.chdir(@output_dir) do
        opf_file = "lemma_greek_#{@source_lang}_#{@download_date}.opf"
        expected_mobi = "lemma_greek_#{@source_lang}_#{@download_date}.mobi"

        # Clean up any existing MOBI file
        if File.exist?(expected_mobi)
          puts "Removing existing MOBI file: #{expected_mobi}"
          File.delete(expected_mobi)
        end

        # Clean up any existing log files
        Dir.glob("*.log").each do |log_file|
          puts "Removing existing log file: #{log_file}"
          File.delete(log_file)
        end

        cmd = "\"#{kindle_previewer}\" #{opf_file} -convert -output ."

        puts "Running: #{cmd}"
        puts "This may take several minutes for large dictionaries..."

        success = system(cmd)

        if success
          # Check for the generated MOBI file
          if File.exist?(expected_mobi)
            puts "\nSuccess! Generated #{expected_mobi}"
            puts "Dictionary type: #{@source_lang == 'en' ? 'Greek-English' : 'Greek-Greek (monolingual)'}"
            puts "File size: #{(File.size(expected_mobi) / 1024.0 / 1024.0).round(2)} MB"
            puts "You can now transfer this file to your Kindle device."
          else
            # Look in subdirectories if not found in current directory
            mobi_files = Dir.glob("**/*.mobi")
            if mobi_files.any?
              puts "\nMOBI file found at: #{mobi_files.first}"
              puts "You may need to move it to your desired location."
            else
              puts "\nWarning: Command completed but MOBI file not found."
              puts "Check the output directory for generated files."
            end
          end
        else
          puts "\nError: Failed to generate MOBI file."
          puts "You can try opening #{@output_dir}/#{opf_file} manually in Kindle Previewer."
        end
      end
    else
      puts "\nKindle Previewer not found. Please install it from:"
      puts "https://www.amazon.com/gp/feature.html?docId=1000765261"
      puts "\nOnce installed, you can manually convert the dictionary:"
      puts "1. Open Kindle Previewer"
      puts "2. File > Open > #{@output_dir}/lemma_greek_#{@source_lang}_#{@download_date}.opf"
      puts "3. File > Export > .mobi"
    end
  end

  def escape_html(text)
    return "" unless text
    text.gsub(/&/, '&amp;')
        .gsub(/</, '&lt;')
        .gsub(/>/, '&gt;')
        .gsub(/"/, '&quot;')
        .gsub(/'/, '&#39;')
  end
end

# Run the generator
if __FILE__ == $0
  options = {}

  parser = OptionParser.new do |opts|
    opts.banner = "Usage: ruby greek_kindle_dictionary.rb [options]"

    opts.on("-s", "--source LANG", "Source Wiktionary language: 'en' (English) or 'el' (Greek). Default: en") do |lang|
      unless ['en', 'el'].include?(lang)
        puts "Error: Source must be 'en' or 'el'"
        exit 1
      end
      options[:source] = lang
    end

    opts.on("-h", "--help", "Show this help message") do
      puts opts
      exit
    end
  end

  parser.parse!

  source_lang = options[:source] || 'en'
  generator = GreekKindleDictionary.new(source_lang)
  generator.generate
end
