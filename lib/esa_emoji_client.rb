require 'esa'

class EsaEmojiClient
  class TooManyRequestError < StandardError; end

  def initialize(esa_access_token, esa_team_name, dry_run)
    @esa_client = Esa::Client.new(
      access_token: esa_access_token,
      current_team: esa_team_name
    )
    @dry_run = dry_run

    endpoint = "https://api.esa.io/v1/teams/#{esa_team_name}/emojis"
    headers = { 'Authorization' => "Bearer #{esa_access_token}" }

    uri = URI.parse(endpoint)
    @https = Net::HTTP.new(uri.host, uri.port)
    @https.use_ssl = true
    @request = Net::HTTP::Post.new(uri.path, initheader = headers)
    @existing_emojis = []
  end

  def get_all_custom_emojis
    @existing_emojis = @esa_client.emojis.body['emojis'] if @existing_emojis.empty?
    return @existing_emojis.select {|emoji| emoji['category'] == "Custom"}
  end

  def add(emoji, filepath)
    unless allowed_name?(emoji.name)
      puts "[ERROR] 絵文字の名前( :#{emoji.name}: ) には小文字の英数字と、アンダースコア(_)、ハイフン(-)のみが使用できます。"
      return
    end

    unless allowed_extension?(emoji.extension)
      puts "[ERROR] esaで許可されていない画像形式(.#{emoji.extension})です。"
      return
    end

    if @dry_run
      puts "[INFO] :#{emoji.name}: を登録しました。"
      return
    end

    image_file_name = emoji.filename
    image_file = File.open(filepath, "r")

    data = [
      [
        'emoji[code]', emoji.name
      ],
      [
        'emoji[image]',
        image_file, {
          filename: emoji.filename,
          content_type: "image/#{emoji.extension}"
        }
      ]
    ]

    post_emoji(data, emoji)
    image_file.close
  end

  def add_alias(name, target_name)
    unless allowed_name?(name)
      puts "[ERROR] 絵文字の名前( :#{name}: ) には小文字の英数字と、アンダースコア(_)、ハイフン(-)のみが使用できます。"
      return
    end

    if @dry_run
      puts "[INFO] :#{name}: を :#{target_name}: のエイリアスとして登録しました。"
      return
    end

    response = @esa_client.create_emoji(code: name, origin_code: target_name)

    if response.body['error'].nil?
      puts "[INFO] :#{name}: を :#{target_name}: のエイリアスとして登録しました。"
    else
      puts "[ERROR] エイリアス対象の :#{target_name}: が見つからないか、 :#{name}: がすでに登録されています。"
    end
  end

  def remove_all
    emojis = get_all_custom_emojis
    emojis.each do |emoji|
      code = emoji['code']
      remove(code)
      sleep 1 unless @dry_run
    end
  end

  def remove(code)
    if @dry_run
      puts "[INFO] :#{code}: をesaから削除しました。"
    else
      response = @esa_client.delete_emoji(code)

      if response.body.nil?
        puts "[INFO] :#{code}: をesaから削除しました。"
      else
        puts "[ERROR] #{response.body['message']}"
      end
    end
  end

  private
  def allowed_name?(name)
    return (/[a-z\-_]+/ =~ name)
  end

  def allowed_extension?(extension)
    allowed_extensions = ['png', 'jpg', 'jpeg', 'gif']
    return allowed_extensions.include?(extension)
  end

  def post_emoji(data, emoji)
    @request.set_form(data, "multipart/form-data")
    response = @https.request(@request)
    raise TooManyRequestError if response.code == '429' # too_many_requests
    json = JSON.parse(response.body)
    if json['error'].nil?
      puts "[INFO] :#{emoji.name}: を登録しました。"
    else
      puts "[ERROR] #{json['message']}"
    end
  rescue TooManyRequestError
    headers = response.each_header.to_h
    wait_sec = headers['retry-after'].to_i + 5
    puts "Rate limit exceeded: will retry after #{wait_sec} seconds."
    wait_for(wait_sec)
    retry
  end

  def wait_for(wait_sec)
    return if wait_sec <= 0

    (wait_sec / 10).times do
        print '.'
        sleep 10
    end
    sleep wait_sec % 10
      puts
  end
end
