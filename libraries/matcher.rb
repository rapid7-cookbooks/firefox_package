if defined?(ChefSpec)
  ChefSpec.define_matcher :firefox_package
  
  def install_firefox_package(resource_name)
    ChefSpec::Matchers::ResourceMatcher.new(:firefox_package, :install, resource_name)
  end

  def upgrade_firefox_package(resource_name)
    ChefSpec::Matchers::ResourceMatcher.new(:firefox_package, :upgrade, resource_name)
  end

  def remove_firefox_package(resource_name)
    ChefSpec::Matchers::ResourceMatcher.new(:firefox_package, :remove, resource_name)
  end
end
