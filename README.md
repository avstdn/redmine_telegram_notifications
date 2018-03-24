# Telegram notifications for Redmine

## Installation

Clone plugin:

    git clone https://github.com/avstdn/redmine_telegram_notifications

Install `httpclient` dependency:

    bundle install

Make migration:

    bundle exec rake redmine:plugins:migrate RAILS_ENV=production

Restart Redmine.

Enjoy.

## Update plugin

Pull new version of plugin:
	
    git pull origin master

Start migration:

    bundle exec rake redmine:plugins:migrate RAILS_ENV=production

Restart Redmin.

## Uninstall

Make migration down command:

    bundle exec rake redmine:plugins:migrate NAME=redmine_telegram_notifications VERSION=0 RAILS_ENV=production
    
Delete plugin from Redmine plugins folder
  
Restart Redmine
