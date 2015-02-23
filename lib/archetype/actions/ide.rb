description = "Generate IDE code snippets for an archetype theme"

require "sass"
require 'sass/plugin'
require "compass"
require "archetype"
require "archetype-theme"
require "compass-import-once"


if @description.nil?
  options = {
    :themepath => 'archetype',
    :themename => 'archetype',
    :output => ''
  }
  OptionParser.new do |opts|
    opts.banner = description
    opts.define_head "Usage: #{Archetype.name} ide [theme] [output]"
    opts.separator ""
    opts.separator "Example usage:"
    opts.separator " #{Archetype.name} ide --output=/path/to/output/directory"
    opts.separator " #{Archetype.name} ide --theme-path=/path/to/theme/core.scss --output=/path/to/output/directory"

    opts.on('-t', '--theme-path THEME', 'path to theme core.scss file') do |v|
      options[:themepath] = v
    end

    opts.on('-f', '--file-prefix NAME', 'prefix your IDE files with this name. Defaults to your theme name, or "archetype" ') do |v|
      options[:themename] = v
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

  def get_theme_name(theme_name, theme_path, tmp_dir)
    puts "Getting theme name..."
    theme_name_file = "#{tmp_dir}/theme_name.scss"
    theme_name_css_file = theme_name_file + ".css"

    content_for_file = "@import \"" + File.expand_path(theme_path) + "\";\n/*\#{$CONFIG_THEME}*/"

    File.open(theme_name_file, "w") { |file| file.puts content_for_file  }
    Compass.compiler.compile(theme_name_file, theme_name_css_file)

    #Strip out all the comment deliminters
    out = File.read(theme_name_css_file).gsub(/\/\*/,'').gsub(/\*\//,'')
    File.open(theme_name_css_file, "w") { |file| file.puts out }

    contents = IO.readlines theme_name_css_file
    if contents.length > 0
      #Strip whitespace from name
      theme_name = contents[0].gsub(/\s+/, "")
    else
      puts "Could not get theme name. Defaulting to '#{theme_name}'"
    end
    FileUtils.rm(theme_name_file)
    return theme_name
  end

  def create_ide_file(theme_name, theme_path, filename, output_dir)
    base_name = File.basename(filename, ".*")
    namespaced_name = "#{theme_name}-#{base_name}"
    contents = []
    css_name = filename + '.css'
    css_output = css_name

    #if it isn't 'archetype', then it's a user-defined theme
    if theme_path != 'archetype'
      scss_out = File.read(filename).gsub(/\/\/Replace/,'@import "' + File.expand_path(theme_path) + '";')
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
    File.open(output_dir + "/#{namespaced_name}.sublime-completions", "w") { |file| file.puts all_content.join }
  end

  if not options[:output].nil?
    base = ARGV[1] || '.'
    tmp = '/tmp/ide_' + rand(36**8).to_s(36)
    theme_template = File.join(File.dirname(__FILE__), '../../../templates/_ide/')
    theme_path = options[:themepath]
    output = options[:output]
    theme_name = options[:themename]

    # copy template files to tmp dir
    FileUtils.mkdir_p(tmp)
    FileUtils.cp_r(Dir["#{theme_template}/**"], tmp)

    # Try to get the actual theme name if a path was provided, and the default theme_name
    # is still being used.
    if theme_path != 'archetype' && theme_name == 'archetype'
      theme_name = get_theme_name(theme_name, theme_path, tmp)
    end

    puts "Creating sublime autocompletions for #{theme_name} to #{File.expand_path(output)}..."

    # compile and grab all component & variants, icons from theme
    Dir.glob("#{tmp}/**/*.scss") do |file_name|
      create_ide_file(theme_name, theme_path, file_name, output)
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