#!/usr/bin/env ruby
#
#  greek_kindle_dictionary.rb
#  Lemma - Greek Kindle Dictionary Generator
#
#  Created by Francisco Riordan on 4/22/25.
#

require 'optparse'
require_relative 'lib/greek_dictionary_generator'
require_relative 'lib/greek_letter_pairs'

# Run the generator
if __FILE__ == $0
  options = {}
  total_parts = GreekLetterPairs.total_parts

  parser = OptionParser.new do |opts|
    opts.banner = "Usage: ruby greek_kindle_dictionary.rb [options]"

    opts.on("-s", "--source LANG", "Source Wiktionary language: 'en' (English) or 'el' (Greek). Default: en") do |lang|
      unless ['en', 'el'].include?(lang)
        puts "Error: Source must be 'en' or 'el'"
        exit 1
      end
      options[:source] = lang
    end

    opts.on("-l", "--limit PERCENT", "Limit to first PERCENT% of words (for testing). Default: 100") do |percent|
      percent_value = percent.to_f
      unless percent_value > 0 && percent_value <= 100
        puts "Error: Limit must be between 0 and 100"
        exit 1
      end
      options[:limit] = percent_value
    end

    opts.on("-p", "--part NUMBER", "For Greek source (-s el), generate specific part (1-#{total_parts})") do |part|
      part_num = part.to_i
      unless (1..total_parts).include?(part_num)
        puts "Error: Part must be between 1 and #{total_parts}"
        exit 1
      end
      options[:part] = part_num
    end

    opts.on("-h", "--help", "Show this help message") do
      puts opts
      puts "\nGreek dictionary parts (for -s el):"
      GreekLetterPairs.get_letter_pairs.each_with_index do |pair, i|
        puts "  Part #{i + 1}: #{pair.join('-').rjust(5)}"
      end
      exit
    end
  end

  parser.parse!

  source_lang = options[:source] || 'en'
  limit_percent = options[:limit]
  split_part = options[:part]

  # Validate split part is only for Greek source
  if split_part && source_lang != 'el'
    puts "Error: Split parts (-p) can only be used with Greek source (-s el)"
    exit 1
  end

  # If Greek source without specific part, generate all parts
  if source_lang == 'el' && !split_part && !limit_percent
    puts "Generating all #{total_parts} parts of Greek monolingual dictionary..."
    puts "Dictionary will be split into the following letter groups:"
    GreekLetterPairs.get_letter_pairs.each_with_index do |pair, i|
      puts "  Part #{i + 1}: #{pair.join('-').rjust(10)}"
    end

    # First, download the data once
    puts "\n" + "="*60 + "\n"
    puts "DOWNLOADING DATA (once for all parts)"
    puts "="*60 + "\n"

    # Create a generator just for downloading
    downloader = GreekDictionaryGenerator.new(source_lang, limit_percent, 1, total_parts)
    downloader.download_data_once

    # Get the download date and extraction date to use for all parts
    download_date = downloader.download_date
    extraction_date = downloader.extraction_date

    # Now generate each part using the already downloaded data
    puts "\n" + "="*60 + "\n"

    total_parts.times do |i|
      part_num = i + 1
      puts "GENERATING PART #{part_num} of #{total_parts} (Letters #{GreekLetterPairs.get_letter_pairs[i].join('-')})"
      generator = GreekDictionaryGenerator.new(source_lang, limit_percent, part_num, total_parts)

      # Set the download date to match the downloader
      generator.update_download_date(download_date)

      # Also set extraction date if we found one
      if extraction_date
        generator.set_extraction_date(extraction_date)
      end

      generator.generate_from_existing_data

      puts "\n" + "="*60 + "\n"
    end

    puts "All #{total_parts} parts generated successfully!"
  else
    # For English, never split (pass nil for split_part even if specified)
    if source_lang == 'en' && split_part
      puts "Note: English dictionaries are not split into parts. Generating complete dictionary."
      split_part = nil
    end

    parts_count = source_lang == 'el' ? total_parts : 1
    generator = GreekDictionaryGenerator.new(source_lang, limit_percent, split_part, parts_count)
    generator.generate
  end
end
