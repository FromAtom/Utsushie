require 'esa'

class EmojiRemover
  def initialize(esa_access_token, esa_team_name, dry_run)
    @dry_run = dry_run
    @esa_client = Esa::Client.new(
      access_token: esa_access_token,
      current_team: esa_team_name
    )
  end

  def remove_all
    emojis = get_all_custom_emojis
    emojis.each do |emoji|
      code = emoji['code']

      if @dry_run
        puts "[INFO] :#{code}: をesaから削除しました。"
      else
        response = @esa_client.delete_emoji(code)

        if response.body.nil?
          puts "[INFO] :#{code}: をesaから削除しました。"
        else
          puts "[ERROR] #{response.body['message']}"
        end
        sleep 1
      end
    end
  end

  private
  def get_all_custom_emojis
    emojis = @esa_client.emojis.body['emojis']
    return emojis.select {|emoji| emoji['category'] == "Custom"}
  end
end
