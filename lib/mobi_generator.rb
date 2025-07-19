#
#  lib/mobi_generator.rb
#  Handles MOBI file generation using Kindle Previewer
#
#  Created by Francisco Riordan on 4/22/25.
#

require 'shellwords'

class MobiGenerator
  def initialize(generator, opf_filename = nil)
    @generator = generator
    @output_dir = generator.output_dir
    @opf_filename = opf_filename
  end

  def generate
    puts "\nGenerating MOBI file with Kindle Previewer..."

    kindle_previewer_paths = [
      "/Applications/Kindle Previewer 3.app/Contents/lib/fc/bin/kindlepreviewer",
      "/Applications/Kindle Previewer.app/Contents/lib/fc/bin/kindlepreviewer",
      "#{ENV['HOME']}/Applications/Kindle Previewer 3.app/Contents/lib/fc/bin/kindlepreviewer",
      "kindlepreviewer"
    ]

    kindle_previewer = kindle_previewer_paths.find { |path| File.exist?(path) || system("which #{Shellwords.escape(path)} > /dev/null 2>&1") }

    if kindle_previewer
      Dir.chdir(@output_dir) do
        # Use the provided OPF filename or construct it
        if @opf_filename
          opf_file = @opf_filename
        elsif @generator.split_part
          opf_file = "lemma_greek_#{@generator.source_lang}_#{@generator.download_date}_part#{@generator.split_part}.opf"
        else
          opf_file = "lemma_greek_#{@generator.source_lang}_#{@generator.download_date}.opf"
        end

        # Expected MOBI filename matches OPF name
        expected_mobi = opf_file.sub('.opf', '.mobi')

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

        puts "Running Kindle Previewer on #{opf_file}"
        puts "This may take several minutes for large dictionaries..."

        success = system(kindle_previewer, opf_file, "-convert", "-output", ".")

        if success
          # Check for the generated MOBI file
          if File.exist?(expected_mobi)
            puts "\nSuccess! Generated #{expected_mobi}"
            dict_type = @generator.source_lang == 'en' ? 'Greek-English' : 'Greek-Greek (monolingual)'
            if @generator.split_part
              puts "Dictionary type: #{dict_type} - Part #{@generator.split_part} of #{@generator.total_parts}"
            else
              puts "Dictionary type: #{dict_type}"
            end
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
      puts "2. File > Open > #{@output_dir}/#{@opf_filename || 'lemma_greek_*.opf'}"
      puts "3. File > Export > .mobi"
    end
  end
end
