#
#  lib/html_generator.rb
#  Generates HTML files for the dictionary
#
#  Created by Francisco Riordan on 4/22/25.
#

require 'fileutils'

class HtmlGenerator
  def initialize(generator)
    @generator = generator
    @entries = generator.entries
    @output_dir = generator.output_dir
    @letter_range = nil  # Initialize this
  end

  def create_output_files
    # Initialize with base output dir
    update_output_dir

    # Clean up existing directory if it exists
    if Dir.exist?(@output_dir)
      puts "Removing existing directory: #{@output_dir}"
      FileUtils.rm_rf(@output_dir)
    end

    FileUtils.mkdir_p(@output_dir)

    # Create content first to determine letter range
    create_content_html

    # If we have a letter range, update the output directory name
    if @generator.split_part && @letter_range
      old_dir = @output_dir
      update_output_dir

      # Rename directory if it changed
      if old_dir != @output_dir
        FileUtils.mv(old_dir, @output_dir)
      end
    end

    create_cover_html
    create_copyright_html
    create_usage_html
    create_opf_file
  end

  def opf_filename
    @opf_filename
  end

  def letter_range
    @letter_range
  end

  private

  def update_output_dir
    if @output_dir.nil? || @output_dir.empty?
      puts "Error: Output directory is nil or empty!"
      @output_dir = "lemma_greek_#{Time.now.strftime('%Y%m%d')}"
      puts "Using fallback directory: #{@output_dir}"
    end

    # Add suffixes based on options
    if @generator.limit_percent
      @output_dir = "#{@output_dir}_#{@generator.limit_percent}pct"
    end

    if @generator.split_part && @letter_range
      # Use letter range in directory name
      safe_range = @letter_range.gsub(/[^Α-Ωα-ω0-9\-]/, '')
      @output_dir = "#{@output_dir}_#{safe_range}"
    elsif @generator.split_part
      @output_dir = "#{@output_dir}_part#{@generator.split_part}"
    end

    @generator.update_output_dir(@output_dir)
  end

  def normalize_for_sorting(word)
    # Convert to string if it's a symbol
    word_str = word.to_s

    # Remove accents and normalize for sorting
    normalized = word_str.downcase

    # Greek accent removal mapping
    accent_map = {
      'ά' => 'α', 'έ' => 'ε', 'ή' => 'η', 'ί' => 'ι',
      'ό' => 'ο', 'ύ' => 'υ', 'ώ' => 'ω',
      'ΐ' => 'ι', 'ΰ' => 'υ', 'ϊ' => 'ι', 'ϋ' => 'υ',
      'Ά' => 'α', 'Έ' => 'ε', 'Ή' => 'η', 'Ί' => 'ι',
      'Ό' => 'ο', 'Ύ' => 'υ', 'Ώ' => 'ω'
    }

    accent_map.each { |accented, plain| normalized.gsub!(accented, plain) }

    # Remove punctuation and special characters
    normalized.gsub!(/[^\p{Greek}\p{Latin}0-9]/, '')

    normalized
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

    # Sort entries alphabetically with normalized sorting
    sorted_entries = @entries.sort_by { |word, _| normalize_for_sorting(word) }

    # Handle splitting for Greek monolingual dictionary only
    if @generator.source_lang == 'el' && @generator.split_part && @generator.total_parts > 1
      total_entries = sorted_entries.size
      entries_per_part = (total_entries.to_f / @generator.total_parts).ceil

      start_index = (@generator.split_part - 1) * entries_per_part
      end_index = [@generator.split_part * entries_per_part - 1, total_entries - 1].min

      sorted_entries = sorted_entries[start_index..end_index]
      @letter_range = "#{sorted_entries.first[0]}-#{sorted_entries.last[0]}" if sorted_entries.any?

      puts "Part #{@generator.split_part}: #{sorted_entries.size} entries"
      puts "Range: #{sorted_entries.first[0]} - #{sorted_entries.last[0]}" if sorted_entries.any?
      puts "Indices: #{start_index} to #{end_index} of #{total_entries} total"

    elsif @generator.limit_percent && sorted_entries.size > 0
      # Calculate how many entries to include
      max_words = (sorted_entries.size * @generator.limit_percent / 100.0).ceil
      sorted_entries = sorted_entries.first(max_words)
      puts "Limited dictionary to #{sorted_entries.size} headwords (#{@generator.limit_percent}% of #{@entries.size})"
    end

    # Add main entries
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
      pos_display = format_pos(entry[:pos])

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

  def format_pos(pos)
    pos_display = pos || "unknown"

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
    if @generator.source_lang == 'el' && pos_map[pos_display.downcase]
      pos_map[pos_display.downcase]
    else
      pos_display
    end
  end

  def create_cover_html
    source_desc = @generator.source_lang == 'en' ? 'English Wiktionary' : 'Greek Wiktionary (Monolingual)'
    date_info = @generator.extraction_date ? "Wiktionary data from: #{@generator.extraction_date}" : "Downloaded: #{@generator.download_date}"

    if @generator.split_part && @letter_range
      part_info = "Letters #{@letter_range}\n"
    elsif @generator.split_part
      part_info = "Part #{@generator.split_part} of #{@generator.total_parts}\n"
    else
      part_info = ""
    end

    File.write("#{@output_dir}/cover.html", <<~HTML)
      <html>
        <head>
          <meta content="text/html; charset=utf-8" http-equiv="content-type">
        </head>
        <body>
          <h1>Lemma Greek Dictionary</h1>
          <h3>From #{source_desc}</h3>
          #{part_info}
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
          <p>Wiktionary data extracted: #{@generator.extraction_date || 'Unknown'}</p>
          <p>Dictionary created: #{@generator.download_date}</p>
        </body>
      </html>
    HTML
  end

  def create_usage_html
    dict_type = @generator.source_lang == 'en' ? 'Greek-English' : 'Greek-Greek (monolingual)'

    File.write("#{@output_dir}/usage.html", <<~HTML)
      <html>
        <head>
          <meta content="text/html; charset=utf-8" http-equiv="content-type">
        </head>
        <body>
          <h2>How to Use Lemma Greek Dictionary</h2>
          <p>This is a #{dict_type} dictionary with Modern Greek words from #{@generator.source_lang == 'en' ? 'English' : 'Greek'} Wiktionary.</p>
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
    source_name = @generator.source_lang == 'en' ? 'en-el' : 'el-el'

    # Create unique title and identifier for each part
    if @generator.split_part && @letter_range
      unique_id = "LemmaGreek#{source_name.upcase.gsub('-', '')}#{@letter_range.gsub(/[^Α-Ωα-ω0-9\-]/, '')}"
      display_title = "Lemma Greek #{source_name.upcase} Letters #{@letter_range}"
    elsif @generator.split_part
      unique_id = "LemmaGreek#{source_name.upcase.gsub('-', '')}Part#{@generator.split_part}"
      display_title = "Lemma Greek #{source_name.upcase} Part #{@generator.split_part}"
    else
      unique_id = "LemmaGreek#{source_name.upcase.gsub('-', '')}"
      display_title = "Lemma Greek Dictionary #{source_name.upcase}"
    end

    title_with_date = "#{display_title} (#{@generator.extraction_date || @generator.download_date})"
    out_lang = @generator.source_lang == 'en' ? 'en' : 'el'

    # Create unique filename for each part
    if @generator.split_part
      opf_filename = "lemma_greek_#{@generator.source_lang}_#{@generator.download_date}_#{@letter_range ? @letter_range.gsub(/[^Α-Ωα-ω0-9\-]/, '') : "part#{@generator.split_part}"}.opf"
    else
      opf_filename = "lemma_greek_#{@generator.source_lang}_#{@generator.download_date}.opf"
    end

    File.write("#{@output_dir}/#{opf_filename}", <<~XML)
      <?xml version="1.0"?>
      <package version="2.0" xmlns="http://www.idpf.org/2007/opf" unique-identifier="BookId">
        <metadata>
          <dc:title>#{title_with_date}</dc:title>
          <dc:creator opf:role="aut">Lemma</dc:creator>
          <dc:language>el</dc:language>
          <dc:date>#{@generator.download_date}</dc:date>
          <dc:identifier id="BookId" opf:scheme="UUID">#{unique_id}-#{@generator.download_date}</dc:identifier>
          <meta name="wiktionary-extraction-date" content="#{@generator.extraction_date || 'Unknown'}" />
          <meta name="dictionary-name" content="#{display_title}" />
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

    # Store the OPF filename for use by MobiGenerator
    @opf_filename = opf_filename
  end

  def escape_html(text)
    return "" unless text
    text.to_s.encode('UTF-8', invalid: :replace, undef: :replace)
        .gsub(/&/, '&amp;')
        .gsub(/</, '&lt;')
        .gsub(/>/, '&gt;')
        .gsub(/"/, '&quot;')
        .gsub(/'/, '&apos;')
  end
end
