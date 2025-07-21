#
#  lib/greek_dictionary_generator.rb
#  Main generator class
#
#  Created by Francisco Riordan on 4/22/25.
#

require 'json'
require 'fileutils'
require 'time'
require_relative 'downloader'
require_relative 'entry_processor'
require_relative 'html_generator'
require_relative 'mobi_generator'

class GreekDictionaryGenerator
  attr_reader :source_lang, :limit_percent, :split_part, :total_parts,
              :entries, :lemma_inflections, :extraction_date, :download_date,
              :output_dir

  def initialize(source_lang = 'en', limit_percent = nil, split_part = nil, total_parts = 10)
    unless ['en', 'el'].include?(source_lang)
      raise ArgumentError, "Source language must be 'en' or 'el'"
    end
    @source_lang = source_lang
    @limit_percent = limit_percent
    @split_part = split_part
    @total_parts = total_parts
    @entries = {}
    @lemma_inflections = {}
    @extraction_date = nil
    @download_date = Time.now.strftime("%Y%m%d")
    @output_dir = "lemma_greek_#{@source_lang}_#{@download_date}"

    # Ensure download_date is set
    raise "Download date could not be set" if @download_date.nil? || @download_date.empty?

    puts "Initialized with:"
    puts "  Source: #{source_lang == 'en' ? 'English' : 'Greek'} Wiktionary"
    puts "  Download date: #{@download_date}"
    puts "  Word limit: #{limit_percent ? "#{limit_percent}% of entries" : "All entries"}" if limit_percent
    puts "  Split part: #{split_part} of #{total_parts}" if split_part
  end

  def generate
    puts "Lemma - Greek Kindle Dictionary Generator"
    puts "Download date: #{@download_date}"

    download_data
    process_entries
    create_output_files
    generate_mobi

    puts "\nDictionary generation complete!"
    puts "Files created in #{@output_dir}/"
    puts "Wiktionary extraction date: #{@extraction_date}" if @extraction_date
  end

  def update_output_dir(new_dir)
    @output_dir = new_dir
  end

  def update_download_date(new_date)
    @download_date = new_date
  end

  def set_extraction_date(date)
    @extraction_date = date
  end

  private

  def download_data
    downloader = Downloader.new(@source_lang, @download_date)
    success, filename, actual_date = downloader.download

    if actual_date != @download_date
      @download_date = actual_date
      @output_dir = "lemma_greek_#{@source_lang}_#{@download_date}"
      puts "Updated download date to: #{@download_date}"
    end

    unless success
      puts "Error: Download failed"
      exit 1
    end
  end

  def process_entries
    processor = EntryProcessor.new(self)
    processor.process
  end

  def create_output_files
    html_generator = HtmlGenerator.new(self)
    html_generator.create_output_files
    @opf_filename = html_generator.opf_filename
    @letter_range = html_generator.letter_range
  end

  def generate_mobi
    mobi_generator = MobiGenerator.new(self, @opf_filename)
    mobi_generator.generate
  end

  def letter_range
    @letter_range
  end
end
