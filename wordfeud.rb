=begin
Plugin: Wordfeud
Description: Current games in Wordfeud
Author: [rjp](http://github.com/rjp/slogger-wordfeud/)
Configuration:
  wordfeud_user: username
  wordfeud_pass: password
  wordfeud_tags: "#social #games"
  wordfeud_star_wins: true
Notes:
  - multi-line notes with additional description and information (optional)
=end

require 'feudr/client'

config = { # description and a primary key (username, url, etc.) required
  'wordfeud_description' => ['Main description',
                    'additional notes. These will appear in the config file and should contain descriptions of configuration options',
                    'line 2, continue array as needed'],
  'wordfeud_user' => '', # update the name and make this a string or an array if you want to handle multiple accounts.
  'wordfeud_pass' => '',
  'wordfeud_tags' => '#social #games'
}
# Update the class key to match the unique classname below
$slog.register_plugin({ 'class' => 'Wordfeud', 'config' => config })

# unique class name: leave '< Slogger' but change ServiceLogger (e.g. LastFMLogger)
class Wordfeud < Slogger
  # every plugin must contain a do_log function which creates a new entry using the DayOne class (example below)
  # @config is available with all of the keys defined in "config" above
  # @timespan and @dayonepath are also available
  # returns: nothing
  def do_log
    if @config.key?(self.class.name)
      config = @config[self.class.name]
      # check for a required key to determine whether setup has been completed or not
      if !config.key?('wordfeud_user') || config['wordfeud_user'] == []
        @log.warn("<Service> has not been configured or an option is invalid, please edit your slogger_config file.")
        return
      else
        # set any local variables as needed
        username = config['wordfeud_user']
      end

      if !config.key?('wordfeud_pass') || config['wordfeud_pass'] == []
        @log.warn("<Service> has not been configured or an option is invalid, please edit your slogger_config file.")
        return
      else
        # set any local variables as needed
        password = config['wordfeud_pass']
      end
    else
      @log.warn("<Service> has not been configured or a feed is invalid, please edit your slogger_config file.")
      return
    end
    @log.info("Logging <Service> posts for #{username}")

    wf_client = Feudr::Client.new()
    begin
        wf_client.login_with_email(username, password)
    rescue Error
        # something broke
    end

    games = wf_client.games()

    games.each do |game|
    end

    wordfeud_star_wins = config['wordfeud_star_wins'] || false
    tags = config['tags'] || ''
    tags = "\n\n#{@tags}\n" unless @tags == ''

    today = @timespan

    # Perform necessary functions to retrieve posts

    # create an options array to pass to 'to_dayone'
    # all options have default fallbacks, so you only need to create the options you want to specify
    options = {}
    options['content'] = "## Wordfeud game #24252\n\nContent#{tags}"
    options['datestamp'] = Time.now.utc.iso8601
    options['starred'] = true
    options['uuid'] = %x{uuidgen}.gsub(/-/,'').strip

    # Create a journal entry
    # to_dayone accepts all of the above options as a hash
    # generates an entry base on the datestamp key or defaults to "now"
    sl = DayOne.new
    sl.to_dayone(options)

    # To create an image entry, use `sl.to_dayone(options) if sl.save_image(imageurl,options['uuid'])`
    # save_image takes an image path and a uuid that must be identical the one passed to to_dayone
    # save_image returns false if there's an error

  end

  def helper_function(args)
    # add helper functions within the class to handle repetitive tasks
  end
end
