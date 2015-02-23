description = "Generate IDE code snippets for an archetype theme"

require "sass"
require 'sass/plugin'
require "compass"
require "archetype"
require "archetype-theme"
require "compass-import-once"


if @description.nil?
  options = {
    :theme => 'archetype',
    :output => ''
  }
  OptionParser.new do |opts|
    opts.banner = description
    opts.define_head "Usage: #{Archetype.name} ide [theme] [output]"
    opts.separator ""
    opts.separator "Example usage:"
    opts.separator " #{Archetype.name} ide --output=/path/to/output/directory"
    opts.separator " #{Archetype.name} ide --theme=/path/to/theme/core.scss --output=/path/to/output/directory"

    opts.on('-t', '--theme THEME', 'path to theme core.scss file') do |v|
      options[:theme] = v
    end

    opts.on('-o', '--output PATH', 'folder that will contain the snippets') do |v|
      options[:output] = v
    end

    opts.on('-h', '--help', 'shows this help message') do
      puts opts
      exit
    end

    if not @help.nil?
      puts opts
      exit
    end
  end.parse!

  if not options[:theme].nil?
    base = ARGV[1] || '.'
    tmp = '/tmp/ide_' + rand(36**8).to_s(36)
    theme_template = File.join(File.dirname(__FILE__), '../../../templates/_ide/')
    theme_path = options[:theme]
    output = options[:output]
    theme_name = File.basename(options[:theme])
    # copy template files to tmp dir
    FileUtils.mkdir_p(tmp)
    FileUtils.cp_r(Dir["#{theme_template}/**"], tmp)

    puts "Creating sublime autocompletions for #{theme_path} to #{File.expand_path(output)}..."

    theme_name = 'archetype'
    # compile and grab all component & variants, icons from theme
    Dir.glob("#{tmp}/**/*.scss") do |filename|
      base_name = File.basename(filename, ".*")
      namespaced_name = "#{theme_name}-#{base_name}"
      contents = []
      css_name = filename + '.css'
      css_output = css_name

      #if it isn't 'archetype', then it's a user-defined theme
      if theme_path != 'archetype' && theme_path != 'default'
        scss_out = File.read(filename).gsub(/\/\/Replace/,'@import "' + theme_path + '";')
        File.open(filename, "w") { |file| file.puts scss_out }
      end
      #Compile the SCSS to get the names
      Compass.compiler.compile(filename, css_output)

      #Strip out all the comment deliminters
      out = File.read(css_output).gsub(/\/\*/,'').gsub(/\*\//,'')
      File.open(css_output, "w") { |file| file.puts out }

      #Grab each line, which has a component name
      contents = IO.readlines css_output

      #Create each sublime snippet line
      formatted_contents = []
      contents.each { |component|
        formatted_contents.push "{\"trigger\": \"#{component} \\t #{namespaced_name}\", \"contents\": \"#{component}\" }"
      }

      all_content = ["{\"source\": \"source.scss, meta.property-value.scss\",\"completions\":[",formatted_contents.join(","),"]}"]

      # create completions file _<theme>.scss ...
      File.open(output + "/#{namespaced_name}.sublime-completions", "w") { |file| file.puts all_content.join }
    end

    # remove tmp dir
    FileUtils.rm_rf(tmp)
    puts "Congratulations! Your code snippets have been created!"
    puts "Run this periodically to get the latest components."
    exit
  end
else
  @description = description
end