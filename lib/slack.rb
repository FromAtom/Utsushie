require 'net/http'
require 'json'

class Slack
  END_POINT = 'https://slack.com/api/emoji.list?token='

  def initialize(token)
    @token = token
  end

  def emojis
    json = get_json

    emojis = []
    emojis_hash = json['emoji']
    emojis_hash.each do |name, url|
      emoji = Emoji.new(name, url)
      emojis << emoji
    end

    return emojis
  end

  private
  def get_json
    uri = URI.parse(END_POINT + @token)
    response = Net::HTTP.get_response(uri)
    body = response.body

    return JSON.parse(body)
  end

end
