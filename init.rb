raise "Please install ya2yaml first: gem install ya2yaml" unless {}.respond_to?(:ya2yaml)
ActionController::Base.send(:include, MrT::ActionPack)
ActionView::Base.send(:include, MrT::ActionPack)
