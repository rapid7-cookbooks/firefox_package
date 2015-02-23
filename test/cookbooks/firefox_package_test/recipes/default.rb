{
  'latest-esr' => [ '/usr/bin/firefox-latest-esr' ],
  'latest' => [ '/usr/bin/firefox-latest' ],
  '37.0' => [ '/usr/bin/firefox-37.0' ]
}.map do |version, linkto|
  firefox_package version do
    link linkto
  end
end

include_recipe 'firefox_package_test::default_controls'

