require 'optparse'
require 'open-uri'
require 'fileutils'

require_relative 'lib/emoji'
require_relative 'lib/slack'
require_relative 'lib/emoji_uploader'
require_relative 'lib/emoji_remover'

SLACK_OAUTH_ACCESS_TOKEN = ENV['SLACK_OAUTH_ACCESS_TOKEN']
ESA_ACCESS_TOKEN = ENV['ESA_ACCESS_TOKEN']
ESA_TEAM_NAME = ENV['ESA_TEAM_NAME']
IMAGE_BUFFER_DIR = "images"

if SLACK_OAUTH_ACCESS_TOKEN.nil? || ESA_ACCESS_TOKEN.nil? || ESA_TEAM_NAME.nil?
  puts "[ERROR]: Require ENV['SLACK_OAUTH_ACCESS_TOKEN']." if SLACK_OAUTH_ACCESS_TOKEN.nil?
  puts "[ERROR]: Require ENV['ESA_ACCESS_TOKEN']." if ESA_ACCESS_TOKEN.nil?
  puts "[ERROR]: Require ENV['ESA_TEAM_NAME']." if ESA_TEAM_NAME.nil?
  exit
end

options = ARGV.getopts('', 'clean', 'dry-run')
dry_run = options['dry-run']

if options['clean']
  ## esaに登録されているすべてのemojiを削除する
  emoji_remover = EmojiRemover.new(ESA_ACCESS_TOKEN, ESA_TEAM_NAME, dry_run)
  emoji_remover.remove_all
end

## Slackからすべてのカスタム絵文字を取得
slack = Slack.new SLACK_OAUTH_ACCESS_TOKEN
all_emojis = slack.emojis
alias_emojis, emojis = all_emojis.partition(&:alias?)

## SlackからDLした絵文字画像を保存するフォルダを準備
Dir.mkdir(IMAGE_BUFFER_DIR) if not Dir.exist?(IMAGE_BUFFER_DIR)

emoji_uploader = EmojiUploader.new(ESA_ACCESS_TOKEN, ESA_TEAM_NAME, dry_run)

emojis.each do |emoji|
  path = "./#{IMAGE_BUFFER_DIR}/#{emoji.filename}"

  # EmojiをDLする
  unless dry_run
    open(emoji.url) do |file|
      open(path, "w+b") do |out|
        out.write(file.read)
      end
    end
  end

  emoji_uploader.add(emoji, path)

  unless dry_run
    FileUtils.rm(path)
    sleep 1
  end
end

# エイリアスの登録処理
alias_emojis.each do |emoji|
  emoji_uploader.add_alias(emoji.name, emoji.alias_target_name)
  sleep 1 unless dry_run
end
