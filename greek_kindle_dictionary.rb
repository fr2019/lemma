#!/usr/bin/env ruby
#
#  greek_kindle_dictionary.rb
#  Lemma - Greek Kindle Dictionary Generator
#
#  Created by Francisco Riordan on 4/22/25.
#

require 'optparse'
require_relative 'lib/greek_dictionary_generator'

# Configuration constant for splitting
SPLIT_PARTS = 6

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

    opts.on("-l", "--limit PERCENT", "Limit to first PERCENT% of words (for testing). Default: 100") do |percent|
      percent_value = percent.to_f
      unless percent_value > 0 && percent_value <= 100
        puts "Error: Limit must be between 0 and 100"
        exit 1
      end
      options[:limit] = percent_value
    end

    opts.on("-p", "--part NUMBER", "For Greek source (-s el), generate specific part (1-#{SPLIT_PARTS})") do |part|
      part_num = part.to_i
      unless (1..SPLIT_PARTS).include?(part_num)
        puts "Error: Part must be between 1 and #{SPLIT_PARTS}"
        exit 1
      end
      options[:part] = part_num
    end

    opts.on("-h", "--help", "Show this help message") do
      puts opts
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
    puts "Generating all #{SPLIT_PARTS} parts of Greek monolingual dictionary..."
    puts "\n" + "="*60 + "\n"

    SPLIT_PARTS.times do |i|
      part_num = i + 1
      puts "GENERATING PART #{part_num} of #{SPLIT_PARTS}"
      generator = GreekDictionaryGenerator.new(source_lang, limit_percent, part_num, SPLIT_PARTS)
      generator.generate

      puts "\n" + "="*60 + "\n"
    end

    puts "All #{SPLIT_PARTS} parts generated successfully!"
  else
    # For English, never split (pass nil for split_part even if specified)
    if source_lang == 'en' && split_part
      puts "Note: English dictionaries are not split into parts. Generating complete dictionary."
      split_part = nil
    end

    total_parts = source_lang == 'el' ? SPLIT_PARTS : 1
    generator = GreekDictionaryGenerator.new(source_lang, limit_percent, split_part, total_parts)
    generator.generate
  end
end
