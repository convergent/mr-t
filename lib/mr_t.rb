module MrT

  def t(key, options = {})
    reraise = options[:raise]
    defaults = translation_defaults(key, options[:default])
    default = defaults.pop
    I18n.t(defaults.shift, options.merge(:default => defaults.collect(&:to_sym), :raise => true))
  rescue I18n::MissingTranslationData => e
    write_missing_yaml(defaults.first, default)
    raise e if reraise
    default_html(default)
  end
  alias_method :translate, :t

  private

  def write_missing_yaml(key, value = nil)
    file_name = File.dirname(I18n.load_path.last) + "/missing_#{I18n.locale}.yml"
    translations = File.exist?(file_name) ? YAML::load(IO.read(file_name)) : nil
    translations ||= {}
    translations.deep_merge!(I18n.locale.to_s => key_to_hash(key.to_s, value))
    File.open(file_name, 'w') do |f|
      f.write(translations.to_yaml.sub("---", "# Automatically generated from missing files\n# Last updated: #{Time.now}\n"))
    end
  end

  def key_to_hash(key, value = nil)
    value ||= key
    splitted = key.split('.')
    last = splitted.pop
    splitted.reverse.inject({last => value}) do |hash, it|
      hash = { it => hash }
    end
  end

  def default_html(value)
   "<span class=\"missing_translation_data\">#{value}</span>"
  end

  def translation_defaults(key, default = nil)
    app_views = [ join(params[:controller], params[:action]).gsub("/",".") ]
    app_views += app_view_caller
    app_views += app_commons(app_views)
    app_views.uniq!
    key, default = convert_key_and_default(key, default) unless default
    app_views.collect{|it|join(it,key)} << key << default
  end

  def app_commons(app_views)
    app_commons = cumulative_array(app_views.last.split("."))
    app_commons.shift
    app_commons
  end
  
  def app_view_caller
    caller.select do |it| 
      it.include?("app/views")
    end.collect do |it|
      it.sub(/.*app\/views\//, "").sub(/\.#{template.format}\..*/,"").gsub("/",".")
    end
  end

  def convert_key_and_default(key, default)
    if key.is_a?(Symbol)
      default = key.to_s.humanize
    else
      default = key.to_s
      key = key.to_s.downcase.gsub(/\W+/,"_").to_sym
    end
    [key,default]
  end

  def cumulative_array(array)
    array.collect_with_index do |it, index|
      array[0...(array.size - index)].join(".") + ".__common"
    end
  end

  def join(*args)
    options = args.extract_options!
    options[:separator] ||= "."
    args.join(options[:separator])
  end

end
