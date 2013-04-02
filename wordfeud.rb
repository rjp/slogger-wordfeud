=begin
Plugin: Wordfeud
Description: Current games in Wordfeud
Author: [rjp](http://github.com/rjp/slogger-wordfeud/)
Configuration:
  wordfeud_email: email@place.thing
  wordfeud_pass: password
  wordfeud_tags: "#social #games"
  wordfeud_star_wins: true
Notes:
  - multi-line notes with additional description and information (optional)
=end

require 'time'
require 'feudr/client'
require 'mash' # temporary until feudr makes objects

config = { # description and a primary key (username, url, etc.) required
  'wordfeud_description' => ['Main description',
                    'additional notes. These will appear in the config file and should contain descriptions of configuration options',
                    'line 2, continue array as needed'],
  'wordfeud_user' => '', # update the name and make this a string or an array if you want to handle multiple accounts.
  'wordfeud_email' => '',
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
      if !config.key?('wordfeud_email') || config['wordfeud_email'] == []
        @log.warn("<Service> has not been configured or an option is invalid, please edit your slogger_config file.")
        return
      else
        # set any local variables as needed
        email = config['wordfeud_email']
      end

      if !config.key?('wordfeud_pass') || config['wordfeud_pass'] == []
        @log.warn("<Service> has not been configured or an option is invalid, please edit your slogger_config file.")
        return
      else
        # set any local variables as needed
        password = config['wordfeud_pass']
      end

      begin
          # TODO FIX
          @last_run = Time.parse(config['wordfeud_last_run'])
      rescue
          @last_run = Time.at(0)
      end
    else
      @log.warn("<Service> has not been configured or a feed is invalid, please edit your slogger_config file.")
      return
    end
    @log.info("Logging <Service> posts for #{email}")

    @wf_client = Feudr::Client.new()
    begin
        @wf_user = Mash.new(@wf_client.login_with_email(email, password))
    rescue Error
        # something broke
    end

    post_output = ""
    now = Time.now.to_i
    status = Mash.new(@wf_client.user_status())

    unless status.content.invites_received.empty? then
    end

    unless status.content.invites_sent.empty? then
    end

    old_games = @config[self.class.name]['wordfeud_current_games'] || []
    new_games = []
    games = {}

    status.content.games.each do |game|
        new_games << game.id
    end

    post_games = []
    new_games.each do |game_id|
        post_games << process_game(game_id, old_games)
    end
    puts post_games.compact.map{|g| "* #{g.tagline} +#{g.is_running}"}.join("\n")

    old_games = post_games.compact.reject {|game| game.is_running == true}.map {|game| game.id}

    wordfeud_star_wins = config['wordfeud_star_wins'] || false
    tags = config['tags'] || ''
    tags = "\n\n#{@tags}\n" unless @tags == ''

    today = @timespan

    # Perform necessary functions to retrieve posts
#    p old_games
#    p post_games
    output = ''

    post_games.each do |game|
        output += "#### Game #{game.id}\n"

        board_type = game.board==0 ? 'Standard' : "Random ##{game.board}"
        ruleset = @wf_client.rules(game.ruleset)
        players_byid = Hash[game.players.map {|p| [p.id, p]}]
        p players_byid
        last_play = game.last_move
        last_player = last_play.user_id
        last_player_name = players_byid[last_player].username
        output += "* Scores: "
        output += game.players.map { |player|
            "#{player.username} #{player.score}"
        }.join(', ')
        output += "\n"
        output += "* Game type: #{board_type}, #{ruleset}\n"
        output += "* Last play: #{last_play.main_word} by #{last_player_name}\n"
        output += "* Tiles left: #{game.bag_count}\n"
        output += "\n\n"
    end

    # create an options array to pass to 'to_dayone'
    # all options have default fallbacks, so you only need to create the options you want to specify
    options = {}
    options['content'] = "## Wordfeud games\n\n#{output}#{tags}"
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
    #
    return {
        'wordfeud_current_games' => new_games,
        'wordfeud_finished_games' => old_games
    }
  end

  def helper_function(args)
    # add helper functions within the class to handle repetitive tasks
  end

  def embolden(str, flag)
      if flag == true then
          return "__#{str}__"
      else
          return str
      end
  end

  def process_game(id, current)
      game = nil
      begin
          game = @wf_client.game(id)
      rescue
          return nil
      end

      if current.include?(id) then
          game.state = 'CURRENT'
      else
          game.state = 'NEW'
      end

      if 1 or Time.at(game.updated) > @last_run then
          game_type = "#{game.rules} dictionary, #{game.board}"
          score_list = game.players.map {|p| "#{p['username']} _#{p['score']}_"}.join(' -vs- ')
          game.tagline = "#{game.state} #{game_type}: #{score_list} (#{Time.at(game.updated)} <=> #{@last_run})"
      else
          return nil
      end

      return game
  end
end
