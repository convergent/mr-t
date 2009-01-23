module MrT

  module Common

    def log_fallback(defaults)
      trace = caller.reject { |it| it.include?(__FILE__) }.first.to_s.sub(/(:\d+).*/,"\\1").sub(RAILS_ROOT,"")
      logger.debug "Mr. T says (from #{trace}): #{defaults.inspect}"
    end

    def write_missing_yaml(key, value = nil, locale = nil, comment = nil)
      comment ||= "Automatically generated from missing translation data"
      locale ||= I18n.locale
      filename = "#{RAILS_ROOT}/config/locales/missing_#{locale}.yml"
      value ||= key.split('.').last
      #value = google_translate(I18n.locale, value)
      translations = File.exist?(filename) ? YAML::load(IO.read(filename)) : nil
      translations ||= {}
      translations.deep_merge!(locale.to_s => key_to_hash(key.to_s, value))
      write_yaml(filename, translations, comment)
    end

    def write_yaml(filename, translations, comment = "Mr. T has written a file for you!")
      action = File.exist?(filename) ? "Updated" : "Created"
      File.open(filename, 'w') do |f|
        f.write(yaml(translations).sub("---", "# #{comment}\n# Last updated: #{Time.now}\n"))
      end
      msg = "#{action} locale file: #{File.expand_path(filename)}"
      defined?(logger) ? logger.debug(msg) : puts(msg)
    end

    def key_to_hash(key, value = nil)
      value ||= key
      splitted = key.split('.')
      last = splitted.pop
      splitted.reverse.inject({last => value}) do |hash, it|
        hash = { it => hash }
      end
    end

    def app_commons(app_views)
      app_commons = cumulative_array(app_views.last.split("."))
      app_commons.shift
      app_commons
    end

    def convert_key_and_default(key, default)
      if key.is_a?(Symbol)
        default = key.to_s.humanize
      else
        default = key.to_s
        key = key.to_s.downcase.gsub(/\W+/,"_").sub(/^_/,"").sub(/_$/,"").to_sym
      end
      [key,default]
    end

    def cumulative_array(array)
      collect_with_index(array) do |it, index|
        array[0...(array.size - index)].join(".") + ".__common"
      end
    end

    def join(*args)
      options = args.extract_options!
      options[:separator] ||= "."
      args.join(options[:separator])
    end

    def collect_with_index(array)
      i = -1
      array.collect do |it|
        i += 1
        yield it, i
      end
    end
    
    def yaml(value)
      if value.respond_to?(:yayaml)
        value.ya2yaml.gsub("!ruby/symbol ", ":")
      else
        value.to_yaml
      end
    end

    # Got this from amatsuda's i18n_generators
    # http://github.com/amatsuda/i18n_generators
    def google_translate(locale, word)
      @@cache ||= {}
      return @@cache[word] if @@cache[word]
      begin
        w = CGI.escape ActiveSupport::Inflector.humanize(word)
        uri = "http://ajax.googleapis.com/ajax/services/language/translate?v=1.0&q=#{w}&langpair=en%7C#{locale}"
        logger.debug uri
        json = OpenURI.open_uri(uri).read
        result = ActiveSupport::JSON.decode(json)
        result['responseStatus'] == 200 ? (@@cache[word] = result['responseData']['translatedText']) : word
      rescue => e
        logger.debug %Q[failed to translate "#{word}" into "#{locale}" language.]
        word
      end
    end

    def all_translations
      translations = I18n.load_path.flatten.inject({}) do |t, file|
        v = YAML::load(IO.read(file)) rescue {}
        v = {} unless v.is_a?(Hash)
        t.deep_merge!(v)
      end
    end

    def deep_nillify(hash)
      Hash[hash.collect do |key, value|
        [key, (value.is_a?(Hash) && !value.blank? ? deep_nillify(value) : nil)]
      end]
    end

    def deep_remove_not_nil(hash)
      results = hash
      if results.is_a?(Hash)
        results = Hash[results.collect do |key, value|
          [key, (value.is_a?(Hash) ? deep_remove_not_nil(value) : value)]
        end]
      end
      if results.is_a?(Hash)
        results = Hash[results.select do |key, value|
          value != {} and (value.nil? or value.is_a?(Hash))
        end]
      end
      results
    end

  end

  module ActionPack

    include MrT::Common

    def t(key, options = {})
      reraise = options[:raise]
      defaults = translation_defaults(key, options[:default])
      log_fallback(defaults)
      default = defaults.pop
      I18n.t(defaults.shift, options.merge(:default => defaults.collect(&:to_sym), :raise => true))
    rescue I18n::MissingTranslationData => e
      write_missing_yaml(defaults.first, default)
      raise e if reraise
      default_html(default)
    end

    private

    def translation_defaults(key, default = nil)
      app_views = [ join(params[:controller], params[:action]).gsub("/",".") ]
      app_views += app_view_caller
      app_views += app_commons(app_views)
      app_views.uniq!
      key, default = convert_key_and_default(key, default) unless default
      app_views.collect{|it|join(it,key)} << key << default
    end

    def default_html(value)
     "<span class=\"missing_translation_data\">#{value}</span>"
    end
    
    def app_view_caller
      caller.select do |it| 
        it.include?("app/views")
      end.collect do |it|
        it.sub(/.*app\/views\//, "").sub(/\.#{template.format}\..*/,"").gsub("/",".")
      end
    end

  end


end
