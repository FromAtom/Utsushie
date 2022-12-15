require 'optparse'
require 'open-uri'
require 'fileutils'
require 'dotenv/load'

require_relative 'lib/emoji'
require_relative 'lib/slack'
require_relative 'lib/esa_emoji_client'

SLACK_OAUTH_ACCESS_TOKEN = ENV['SLACK_OAUTH_ACCESS_TOKEN']
ESA_ACCESS_TOKEN = ENV['ESA_ACCESS_TOKEN']
ESA_TEAM_NAME = ENV['ESA_TEAM_NAME']
IMAGE_BUFFER_DIR = "images"
ESA_DEFAULT_EMOJIS = [
  'bowtie',
  'squirrel',
  'neckbeard',
  'metal',
  'fu',
  'feelsgood',
  'finnadie',
  'goberserk',
  'godmode',
  'hurtrealbad',
  'rage1',
  'rage2',
  'rage3',
  'rage4',
  'suspect',
  'trollface',
  'octocat',
  'biohazard',
  'esa',
  'unicorn'
]

if SLACK_OAUTH_ACCESS_TOKEN.nil? || ESA_ACCESS_TOKEN.nil? || ESA_TEAM_NAME.nil?
  puts "[ERROR]: Require ENV['SLACK_OAUTH_ACCESS_TOKEN']." if SLACK_OAUTH_ACCESS_TOKEN.nil?
  puts "[ERROR]: Require ENV['ESA_ACCESS_TOKEN']." if ESA_ACCESS_TOKEN.nil?
  puts "[ERROR]: Require ENV['ESA_TEAM_NAME']." if ESA_TEAM_NAME.nil?
  exit
end

options = ARGV.getopts('', 'clean', 'dry-run')
dry_run = options['dry-run']

esa_emoji_client = EsaEmojiClient.new(ESA_ACCESS_TOKEN, ESA_TEAM_NAME, dry_run)

if options['clean']
  ## esaに登録されているすべてのemojiを削除する
  esa_emoji_client.remove_all
end

## Slackからすべてのカスタム絵文字を取得
slack = Slack.new SLACK_OAUTH_ACCESS_TOKEN
all_emojis = slack.emojis

## esaからすべてのカスタム絵文字を取得
existing_emojis = esa_emoji_client.get_all_custom_emojis

## すでにesaに登録されている絵文字は対象外にする
new_emojis = all_emojis.reject { |emoji| existing_emojis.include?(emoji) || ESA_DEFAULT_EMOJIS.include?(emoji.name) }
alias_emojis, emojis = new_emojis.partition(&:alias?)

## SlackからDLした絵文字画像を保存するフォルダを準備
Dir.mkdir(IMAGE_BUFFER_DIR) if not Dir.exist?(IMAGE_BUFFER_DIR)

emojis.each do |emoji|
  path = "./#{IMAGE_BUFFER_DIR}/#{emoji.filename}"

  # EmojiをDLする
  unless dry_run
    URI.open(emoji.url) do |file|
      open(path, "w+b") do |out|
        out.write(file.read)
      end
    end
  end

  esa_emoji_client.add(emoji, path)

  unless dry_run
    FileUtils.rm(path)
    sleep 1
  end
end

# エイリアスの登録処理
alias_emojis.each do |emoji|
  esa_emoji_client.add_alias(emoji.name, emoji.alias_target_name)
  sleep 1 unless dry_run
end
