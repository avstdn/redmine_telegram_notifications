require 'redmine'

require_dependency 'redmine_telegram_notifications/notifier'

Redmine::Plugin.register :redmine_telegram_notifications do
  name 'Redmine Telegram Notifications'
  author 'Alexey Studenikin'
  url 'https://github.com/avstdn/redmine_telegram_notifications'
  author_url 'https://github.com/avstdn/'
  description 'Redmine Telegram Notifications'
  version '1.0'

  requires_redmine :version_or_higher => '1.0.0'

  settings \
  :default => {
      'callback_url' => 'https://api.telegram.org/bot',
      'channel' => nil,
      'username' => 'redmine',
      'display_watchers' => 'no',
      'auto_mentions' => 'yes',
      'new_include_description' => 1,
      'updated_include_description' => 1,
  },
    :partial => 'settings/telegram_notifications_settings'
end


