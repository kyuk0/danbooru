# Image URLS:
# * https://img.pawoo.net/media_attachments/files/001/297/997/small/c4272a09570757c2.png
# * https://img.pawoo.net/media_attachments/files/001/297/997/original/c4272a09570757c2.png
# * https://pawoo.net/media/lU2uV7C1MMQSb1czwvg
#
# Page URLS:
# * https://pawoo.net/@evazion/19451018
# * https://pawoo.net/web/statuses/19451018
#
# Account URLS:
# * https://pawoo.net/@evazion
# * https://pawoo.net/web/accounts/47806
#
# OAUTH URLS: (NOTE: ID IS DIFFERENT FROM ACCOUNT URL ID)
# * https://pawoo.net/oauth_authentications/17230064

module Sources::Strategies
  class Mastodon < Base
    HOST = %r{\Ahttps?://(?:www\.)?(?<domain>pawoo\.net|baraag\.net)}i
    IMAGE = %r{\Ahttps?://(?:img\.pawoo\.net|baraag\.net(?:/system(?:/cache)?)?)/media_attachments/files/((?:\d+/)+\d+)}
    NAMED_PROFILE = %r{#{HOST}/@(?<artist_name>\w+)}i
    ID_PROFILE = %r{#{HOST}/web/accounts/(?<account_id>\d+)}

    STATUS1 = %r{\A#{HOST}/web/statuses/(?<status_id>\d+)}
    STATUS2 = %r{\A#{NAMED_PROFILE}/(?<status_id>\d+)}

    def domains
      ["pawoo.net", "baraag.net"]
    end

    def site_name
      parsed_url.domain
    end

    def file_host
      case site_name
      when "pawoo.net" then "img.pawoo.net"
      when "baraag.net" then "baraag.net/system"
      else site_name
      end
    end

    def image_url
      image_urls.first
    end

    def image_urls
      if url =~ %r{#{IMAGE}/(?:small|original)/([a-z0-9]+\.\w+)\z}i
        ["https://#{file_host}/media_attachments/files/#{$1}/original/#{$2}"]
      else
        api_response.image_urls
      end
    end

    def page_url
      artist_name = artist_name_from_url
      status_id = status_id_from_url
      return if status_id.blank?

      if artist_name.present?
        "https://#{site_name}/@#{artist_name}/#{status_id}"
      else
        "https://#{site_name}/web/statuses/#{status_id}"
      end
    end

    def profile_url
      if artist_name_from_url.present?
        "https://#{site_name}/@#{artist_name_from_url}"
      elsif api_response.present? && api_response.profile_url.present?
        api_response.profile_url
      end
    end

    def account_url
      return if account_id.blank?
      "https://#{site_name}/web/accounts/#{account_id}"
    end

    def profile_urls
      [profile_url, account_url].compact
    end

    def artist_name
      api_response.account_name
    end

    def artist_name_from_url
      urls.map { |url| url[NAMED_PROFILE, :artist_name] }.compact.first
    end

    def other_names
      [api_response.display_name]
    end

    def account_id
      urls.map { |url| url[ID_PROFILE, :account_id] }.compact.first || api_response.account_id
    end

    def status_id_from_url
      urls.map { |url| url[STATUS1, :status_id] || url[STATUS2, :status_id] }.compact.first
    end

    def artist_commentary_desc
      api_response.commentary
    end

    def tags
      api_response.tags
    end

    def normalize_for_source
      page_url
    end

    def dtext_artist_commentary_desc
      DText.from_html(artist_commentary_desc) do |element|
        if element.name == "a"
          # don't include links to the toot itself.
          media_urls = api_response.json["media_attachments"].map { |attr| attr["text_url"] }
          element["href"] = nil if element["href"].in?(media_urls)
        end
      end.strip
    end

    def api_response
      return {} if status_id_from_url.blank?
      MastodonApiClient.new(site_name, status_id_from_url)
    end
    memoize :api_response
  end
end
