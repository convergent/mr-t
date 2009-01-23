namespace :i18n do

  desc "Combines all translations to single files per locale."
  task :combine => :environment do
    include MrT::Common
    old_files = I18n.load_path.flatten
    translations = old_files.inject({}) do |t, file|
      t.deep_merge!(YAML::load(IO.read(file)))
    end
    translations.each do |locale, t|
      filename = "#{RAILS_ROOT}/config/locales/#{locale}.yml"
      write_yaml(filename, { locale.to_s => t }, "All translations of this locale combined.")
      old_files.delete(filename)
    end
    old_files.select do |f|
      f.include?("#{RAILS_ROOT}/config/locales")
    end.each do |f|
      FileUtils.mv f, "#{f}.bak", :verbose => true
    end
  end
end
