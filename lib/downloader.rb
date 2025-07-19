#
#  lib/downloader.rb
#  Handles downloading dictionary data
#
#  Created by Francisco Riordan on 4/22/25.
#

require 'net/http'
require 'uri'

class Downloader
  KAIKKI_URLS = {
    'en' => "https://kaikki.org/dictionary/Greek/kaikki.org-dictionary-Greek.jsonl",
    'el' => "https://kaikki.org/elwiktionary/Greek/kaikki.org-dictionary-Greek.jsonl"
  }

  # Local fallback files
  LOCAL_FALLBACK_FILES = {
    'en' => 'greek_data_en_20250716.jsonl',
    'el' => 'greek_data_el_20250717.jsonl'
  }

  GITHUB_URLS = {
    'en' => 'https://raw.githubusercontent.com/fr2019/lemma/main/greek_data_en_20250716.jsonl',
    'el' => 'https://raw.githubusercontent.com/fr2019/lemma/main/greek_data_el_20250717.jsonl'
  }

  def initialize(source_lang, download_date)
    @source_lang = source_lang
    @download_date = download_date
  end

  def download
    puts "Downloading Greek data from #{@source_lang == 'en' ? 'English' : 'Greek'} Wiktionary via Kaikki..."

    # Primary URL and target filename
    primary_url = KAIKKI_URLS[@source_lang]
    target_filename = "greek_data_#{@source_lang}_#{@download_date}.jsonl"

    # Try primary URL first
    success = download_from_url(primary_url, target_filename)

    if success
      return [true, target_filename, @download_date]
    end

    # If primary fails, try local fallback file
    local_fallback = LOCAL_FALLBACK_FILES[@source_lang]

    if File.exist?(local_fallback)
      puts "Primary download failed. Using local fallback file: #{local_fallback}"

      # Extract date from fallback filename
      fallback_date = local_fallback.match(/greek_data_#{@source_lang}_(\d{8})\.jsonl/)[1] rescue @download_date

      return [true, local_fallback, fallback_date]
    end

    # If local file doesn't exist, try GitHub fallback
    puts "Primary download failed and local fallback not found. Attempting GitHub fallback..."

    fallback_date = GITHUB_URLS[@source_lang].match(/greek_data_#{@source_lang}_(\d{8})\.jsonl/)[1] rescue @download_date
    fallback_filename = "greek_data_#{@source_lang}_#{fallback_date}.jsonl"

    success = download_from_url(GITHUB_URLS[@source_lang], fallback_filename)

    if success
      puts "GitHub fallback download successful. Using fallback date: #{fallback_date}"
      return [true, fallback_filename, fallback_date]
    else
      puts "Error: All download attempts failed."
      puts "Try downloading manually from: #{GITHUB_URLS[@source_lang]}"
      puts "Save as: #{fallback_filename}"
      return [false, nil, nil]
    end
  end

  private

  def download_from_url(url, filename)
    puts "Attempting to download from: #{url}"
    puts "Parsing URL..."

    begin
      uri = URI(url)
      puts "Host: #{uri.host}, Port: #{uri.port || 'default'}, SSL: #{uri.scheme == 'https'}"

      # Add timeout and progress reporting
      start_time = Time.now
      bytes_downloaded = 0

      Net::HTTP.start(uri.host, uri.port,
                     use_ssl: uri.scheme == 'https',
                     open_timeout: 30,
                     read_timeout: 300) do |http|
        puts "Connected to #{uri.host}"

        request = Net::HTTP::Get.new(uri)
        request['User-Agent'] = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36'

        puts "Sending request..."

        # Stream the response to show progress
        File.open(filename, "w") do |file|
          http.request(request) do |response|
            puts "Response code: #{response.code} #{response.message}"

            case response
            when Net::HTTPSuccess
              total_size = response['Content-Length'].to_i
              puts "Content-Length: #{total_size} bytes (#{(total_size / 1024.0 / 1024.0).round(2)} MB)" if total_size > 0

              response.read_body do |chunk|
                file.write(chunk)
                bytes_downloaded += chunk.bytesize

                # Progress update every 5MB
                if bytes_downloaded % (5 * 1024 * 1024) < chunk.bytesize
                  elapsed = Time.now - start_time
                  speed = bytes_downloaded / elapsed / 1024 / 1024
                  puts "Downloaded: #{(bytes_downloaded / 1024.0 / 1024.0).round(2)} MB @ #{speed.round(2)} MB/s"
                end
              end

              elapsed = Time.now - start_time
              puts "Download complete: #{(bytes_downloaded / 1024.0 / 1024.0).round(2)} MB in #{elapsed.round(2)} seconds"

              # Count lines
              line_count = File.foreach(filename).count
              puts "Downloaded #{line_count} lines to #{filename}"

              return true
            else
              puts "Error: HTTP #{response.code} #{response.message}"
              return false
            end
          end
        end
      end
    rescue Timeout::Error => e
      puts "Timeout error: #{e.message}"
      puts "The download is taking too long. The server might be slow or unresponsive."
      return false
    rescue SocketError => e
      puts "Socket error: #{e.message}"
      puts "Cannot connect to host. Check your internet connection."
      return false
    rescue StandardError => e
      puts "Exception during download: #{e.class}: #{e.message}"
      puts e.backtrace.first(5).join("\n")
      return false
    end
  end
end
