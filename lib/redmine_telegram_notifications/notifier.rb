require 'httpclient'

class TelegramNotifier < Redmine::Hook::Listener

  def speak(msg, channel, attachment=nil, token=nil)
    
    token = Setting.plugin_redmine_telegram_notifications['telegram_bot_token'] if not token
    url = "https://api.telegram.org/bot#{token}/sendMessage"

    params = {}
    params[:chat_id] = channel if channel
    params[:parse_mode] = "HTML"
    params[:disable_web_page_preview] = 1

    if attachment
      for field_item in attachment[:fields] do
        msg = msg +"\r\n"+"<b>"+field_item[:title]+":</b> "+field_item[:value]
      end
      msg = msg + "\r\n<b>Описание:</b> " + attachment[:text] if attachment[:text]
    end

    params[:text] = msg

    Rails.logger.info("TELEGRAM SEND TO: #{channel}")
    Rails.logger.info("TELEGRAM TOKEN EMPTY, PLEASE SET IT IN PLUGIN SETTINGS") if token.nil? || token.empty?

    Thread.new do
      # retries = 0
      begin
        client = HTTPClient.new
        client.connect_timeout = 2
        client.send_timeout = 2
        client.receive_timeout = 2
        client.keep_alive_timeout = 2
        client.ssl_config.timeout = 2
        conn = client.post_async(url, params)
        Rails.logger.info("TELEGRAM SEND CODE: #{conn.pop.status_code}")
      rescue Exception => e
        Rails.logger.warn("TELEGRAM CANNOT CONNECT TO #{url} RETRY ##{retries}, ERROR #{e}")
        # retry if (retries += 1) < 5
      end
    end

  end

  def controller_issues_new_after_save(context={})
    issue = context[:issue]
    channel = channel_for_project issue.project
    token = token_for_project issue.project
    createdAt = issue[:created_on].in_time_zone(ActiveSupport::TimeZone.new("Moscow")).to_s[0, 19]

    Rails.logger.info("\n")

    return unless channel

    msg = "<b>#{l(:field_created_on)}:</b> #{escape issue.author}\n<b>Проект: #{escape issue.project}</b>\n<a href='#{object_url issue}'>#{escape issue}</a> #{mentions issue.description if Setting.plugin_redmine_telegram_notifications['auto_mentions'] == '1'}\n<b>Дата начала:</b> #{createdAt}"

    userId = User.find_by id: issue.assigned_to.id if issue.assigned_to.present?
    telegramLogin = userId.custom_value_for(CustomField.find_by type: "UserCustomField").to_s if userId.present?
    assignedTo = issue.assigned_to.to_s

    if telegramLogin.present?
      assignedTo += "\naka @#{telegramLogin.to_s}"
    end

    attachment = {}
    attachment[:text] = escape issue.description if !issue.description.empty? and Setting.plugin_redmine_telegram_notifications['new_include_description']
    attachment[:fields] = [{
      :title => I18n.t("field_priority"),
      :value => escape(issue.priority.to_s),
      :short => true
    }, {
      :title => I18n.t("field_status"),
      :value => escape(issue.status.to_s),
      :short => true
    }]

    attachment[:fields] << {
      :title => I18n.t("field_assigned_to"),
      :value => escape("#{assignedTo}"),
      :short => true
    } if !issue.assigned_to.to_s.empty?

    attachment[:fields] << {
      :title => I18n.t("field_watcher"),
      :value => escape(issue.watcher_users.join(', ')),
      :short => true
    } if Setting.plugin_redmine_telegram_notifications['display_watchers'] == 'yes'

    speak msg, channel, attachment, token if !issue.assigned_to.to_s.empty?

  end

  def controller_issues_edit_before_save(context={})
    issue = context[:issue]
    # journalAssignee = JournalDetail.find_by prop_key: 'assigned_to_id', journal_id: issue.last_journal_id
    # @oldAssignee = User.find(journalAssignee.value).id if journalAssignee and journalAssignee.value.present?
    @oldAssignee = Issue.find(issue.id).attributes["assigned_to_id"]

    # Rails.logger.info("\n")
    # Rails.logger.info("available_columns: #{available_columns}")
    # Rails.logger.info("field_values:#{field_values}")
    # Rails.logger.info("journalAssignee.inspect: #{journalAssignee.inspect}")
    # Rails.logger.info("issue.last_journal_id: #{issue.last_journal_id}")
    # Rails.logger.info("@oldAssignee: #{@oldAssignee}")
    Rails.logger.info("\n")
  end

  def controller_issues_edit_after_save(context={})
    issue = context[:issue]
    journal = context[:journal]
    updatedAt = issue[:updated_on].in_time_zone(ActiveSupport::TimeZone.new("Moscow")).to_s[0, 19]

    # Rails.logger.info("\n")
    # Rails.logger.info("journalAssignee.inspect: #{journalAssignee.inspect}")
    # Rails.logger.info("issue.last_journal_id: #{issue.last_journal_id}")
    # Rails.logger.info("@oldAssignee: #{@oldAssignee}")
    # Rails.logger.info("issue.assigned_to.id: #{issue.assigned_to.id}") if issue.assigned_to
    Rails.logger.info("\n")

    channel = channel_for_project issue.project
    token = token_for_project issue.project

    return unless channel and Setting.plugin_redmine_telegram_notifications['post_updates'] == '1'

    msg = "<b>#{l(:field_updated_on)}:</b> #{journal.user.to_s}\n<b>Проект: #{escape issue.project}</b>\n<a href='#{object_url issue}'>#{escape issue}</a> #{mentions journal.notes if Setting.plugin_redmine_telegram_notifications['auto_mentions'] == '1'}\n<b>Приоритет:</b> #{escape issue.priority}\n<b>Дата обновления:</b> #{updatedAt}"
    
    userId = User.find_by id: issue.assigned_to.id if issue.assigned_to.present?
    telegramLogin = userId.custom_value_for(CustomField.find_by type: "UserCustomField").to_s if userId.present?
    assignedTo = issue.assigned_to.to_s
    newAssignee = issue.assigned_to.id if issue.assigned_to

    if telegramLogin.present?
      assignedTo += "\naka @#{telegramLogin.to_s}"
    end

    attachment = {}
    attachment[:text] = escape journal.notes if !journal.notes.empty? and Setting.plugin_redmine_telegram_notifications['new_include_description']
    # attachment[:fields] = journal.details.map { |d| detail_to_field d }
    attachment[:fields] = [{
      :title => I18n.t("field_status"),
      :value => escape(issue.status.to_s),
      :short => true
    }, {
      :title => I18n.t("field_assigned_to"),
      :value => escape("#{assignedTo}"),
      :short => true
    }]

    speak msg, channel, attachment, token if !(@oldAssignee == newAssignee)

    @oldAssignee = nil
  end

=begin
  def controller_agile_boards_update_after_save(context={})
    issue = context[:issue]
    journal = issue.journals.last
    channel = channel_for_project issue.project
    token = token_for_project issue.project
    priority_id = 1
    priority_id = Setting.plugin_redmine_telegram_notifications['priority_id_add'].to_i if Setting.plugin_redmine_telegram_notifications['priority_id_add'].present?

    return unless channel and Setting.plugin_redmine_telegram_notifications['post_agile_updates'] == '1'

    msg = "<b>Доска задач Agile</b>\n<b>#{l(:field_updated_on)}:</b> #{journal.user.to_s}\n<b>Проект: #{escape issue.project}</b>\n<a href='#{object_url issue}'>#{escape issue}</a> #{mentions journal.notes if Setting.plugin_redmine_telegram_notifications['auto_mentions'] == '1'}\n<b>Приоритет:</b> #{escape issue.priority}"

    userId = User.find_by id: issue.assigned_to.id if issue.assigned_to.present?
    telegramLogin = userId.custom_value_for(CustomField.find_by type: "UserCustomField").to_s if userId.present?
    assignedTo = issue.assigned_to.to_s

    if telegramLogin.present?
      assignedTo += "\naka @#{telegramLogin.to_s}"
    end

    attachment = {}
    attachment[:text] = escape journal.notes if !journal.notes.empty? and Setting.plugin_redmine_telegram_notifications['new_include_description']
    attachment[:fields] = [{
      :title => I18n.t("field_status"),
      :value => escape(issue.status.to_s),
      :short => true
    }, {
      :title => I18n.t("field_assigned_to"),
      :value => escape("#{assignedTo}"),
      :short => true
    }]

    speak msg, channel, attachment, token if issue.priority_id.to_i >= priority_id
  end
=end

private
  def escape(msg)
    msg.to_s.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;").gsub("[", "\[").gsub("]", "\]").gsub("&lt;pre&gt;", "<code>").gsub("&lt;/pre&gt;", "</code>")
  end

  def object_url(obj)
    if Setting.host_name.to_s =~ /\A(https?\:\/\/)?(.+?)(\:(\d+))?(\/.+)?\z/i
      host, port, prefix = $2, $4, $5
      Rails.application.routes.url_for(obj.event_url({
        :host => host,
        :protocol => Setting.protocol,
        :port => port,
        :script_name => prefix
      }))
    else
      Rails.application.routes.url_for(obj.event_url({
        :host => Setting.host_name,
        :protocol => Setting.protocol
      }))
    end
  end

  def token_for_project(proj)
    return nil if proj.blank?

    cf = ProjectCustomField.find_by_name("Telegram BOT Token")

    return [
        (proj.custom_value_for(cf).value rescue nil),
        Setting.plugin_redmine_telegram_notifications['telegram_bot_token'],
    ].find{|v| v.present?}
  end

  def channel_for_project(proj)
    return nil if proj.blank?

    cf = ProjectCustomField.find_by_name("Telegram Channel")

    val = [
      (proj.custom_value_for(cf).value rescue nil),
      Setting.plugin_redmine_telegram_notifications['channel'],
    ].find{|v| v.present?}

    # Channel name '-' is reserved for NOT notifying
    return nil if val.to_s == '-'
    val
  end

  def detail_to_field(detail)
    if detail.property == "cf"
      key = CustomField.find(detail.prop_key).name rescue nil
      title = key
    elsif detail.property == "attachment"
      key = "attachment"
      title = I18n.t :label_attachment
    else
      key = detail.prop_key.to_s.sub("_id", "")
      title = I18n.t "field_#{key}"
    end

    short = true
    value = escape detail.value.to_s

    case key
    when "title", "subject", "description"
      short = false
    when "tracker"
      tracker = Tracker.find(detail.value) rescue nil
      value = escape tracker.to_s
    when "project"
      project = Project.find(detail.value) rescue nil
      value = escape project.to_s
    when "status"
      status = IssueStatus.find(detail.value) rescue nil
      value = escape status.to_s
    when "priority"
      priority = IssuePriority.find(detail.value) rescue nil
      value = escape priority.to_s
    when "category"
      category = IssueCategory.find(detail.value) rescue nil
      value = escape category.to_s
    when "assigned_to"
      user = User.find(detail.value) rescue nil
      value = escape user.to_s
    when "fixed_version"
      version = Version.find(detail.value) rescue nil
      value = escape version.to_s
    when "attachment"
      attachment = Attachment.find(detail.prop_key) rescue nil
      value = "#{object_url attachment}" if attachment
    when "parent"
      issue = Issue.find(detail.value) rescue nil
      value = "#{object_url issue}" if issue
    end

    value = " - " if value.empty?

    result = { :title => title, :value => value }
    result[:short] = true if short
    result
  end

  def mentions text
    names = extract_usernames text
    names.present? ? "\nTo: " + names.join(', ') : nil
  end

  def extract_usernames text = ''
    if text.nil?
      text = ''
    end

    # Telegram usernames may only contain lowercase letters, numbers,
    # dashes and underscores and must start with a letter or number.
    text.scan(/@[a-z0-9][a-z0-9_\-]*/).uniq
  end
end