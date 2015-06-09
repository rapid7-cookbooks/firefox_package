#
# Cookbook Name:: firefox_package
# Recipe:: default
#
# Copyright (C) 2014 Rapid7, LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not us e this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

class Chef
  class Resource::FirefoxPackage < Resource
    include Poise
    include Chef::DSL::PlatformIntrospection
    actions(:install, :upgrade, :remove)

    attribute(:version, kind_of: String, name_attribute: true)
    attribute(:checksum, kind_of: String)
    attribute(:uri, kind_of: String, default: 'https://download-installer.cdn.mozilla.net/pub/firefox/releases')
    attribute(:language, kind_of: String, default: 'en-US')
    attribute(:platform, kind_of: String, default: lazy { node['os'] })
    attribute(:path, kind_of: String,
              default: lazy { platform_family?('windows') ? 'C:\Program Files (x86)\Mozilla Firefox\\' + "#{version}-#{language}" : "/opt/firefox/#{version}-#{language}" })
    attribute(:splay, kind_of: Integer, default: 0)
    attribute(:link, kind_of: [String, Array, NilClass])
    attribute(:windows_ini, template: true, default_options: lazy {{ install_path: path }})
  end

  class Provider::FirefoxPackage < Provider
    include Poise
    include Chef::DSL::PlatformIntrospection

    def action_install
      converge_by("installing Firefox #{new_resource.version} #{new_resource.language}") do
        notifying_block do
           install_package
        end
      end
    end

    def action_upgrade
      converge_by("upgrading Firfox to version #{new_resource.version}") do
        notifying_block do
          remove_package
          install_package
        end
      end
    end

    def action_remove
      converge_by("removing Firefox #{new_resource.version}") do
        notifying_block do
          remove_package
        end
      end
    end

    def munged_platform
      case new_resource.platform.to_s
      when 'x86_64-linux', 'linux'
        @munged_platform = 'linux-x86_64'
      when 'i386-mingw32', 'windows'
        @munged_platform = 'win32'
      when 'darwin', /^universal.x86_64-darwin\d{2}$/
        @munged_platform = 'mac'
      else
        @munged_platform = new_resource.platform
      end
    end

    def explode_tarball(filename, dest_path)
      directory dest_path do
        recursive true
      end

      execute 'untar-firefox' do
        command "tar --strip-components=1 -xjf #{filename} -C #{dest_path}"
        not_if { ::File.exist?(::File.join(dest_path, 'firefox')) }
      end
    end

    def parse_version(filename)
      version = /(.[0-9]\.[0-9])(\.[1-9])?/.match(filename)
      version
    end

    def windows_long_version(version)
      if version.nil?
        version = parse_version(filename)
        long_version = "#{version}"
        if esr?(filename)
          long_version = "#{parse_version(filename)} ESR"
        end
      else
        long_version = version
      end
    end


    def esr?(filename)
      version = /esr/.match(filename)

      if version
        true
      else
        false
      end
    end

    def windows_installer(filename, version, lang, req_action)

      rendered_ini = ::File.join(Chef::Config[:file_cache_path], "firefox-#{version}.ini")

      file rendered_ini do
        content new_resource.windows_ini_content
      end

      windows_package "Mozilla Firefox #{windows_long_version(version)} (x86 #{lang})" do
        source filename
        installer_type :custom
        options "-ms /INI=\"#{rendered_ini}\""
        action req_action
      end
    end

    def requested_version_filename(download_uri)
      unless platform_family?('windows')
        include_recipe 'build-essential::default'
      end

      chef_gem 'oga' do
        compile_time true
      end

      require 'net/http'
      require 'oga'
      require 'digest/sha1'

      uri = URI.parse(download_uri)
      http = Net::HTTP.new(uri.host, uri.port)
      if uri.port == 443
        http.use_ssl = true
        http.ssl_version = :TLSv1
        http.ca_file = Chef::Config[:ssl_ca_file] if Chef::Config[:ssl_ca_file]
      end

      cached_filename = ::File.join(Chef::Config[:file_cache_path], ::Digest::SHA1.hexdigest(download_uri))

      unless ::File.exists?(cached_filename) && ::File.mtime(cached_filename) > Time.now - (60 * new_resource.splay) && ! ::File.zero?(cached_filename)

        request = Net::HTTP::Get.new(uri.request_uri)
        response = http.request(request)
        doc = Oga.parse_html(response.body)

        converge_by("Updating Firefox filename cache: #{cached_filename}") do
          f = ::File.open(cached_filename, 'w')
          f.write(doc.xpath('string(/html/body/table/tr[4]/td[2])'))
          f.close
        end
      end

      @requested_version_filename = ::File.read(cached_filename)
    end

    def install_package
      require 'uri'

      platform = munged_platform
      download_uri = "#{new_resource.uri}/#{new_resource.version}/#{platform}/#{new_resource.language}/"
      filename = requested_version_filename(download_uri)
      cached_file = ::File.join(Chef::Config[:file_cache_path], filename)

      remote_file cached_file do
        source URI.encode("#{download_uri}/#{filename}").to_s
        # If no checksum is specified, assume any existing file is
        # correct to reduce download overhead.
        if new_resource.checksum.nil?
          action :create_if_missing
        else
          checksum new_resource.checksum
          action :create
        end
      end

      if platform == 'win32'
        windows_installer(cached_file, new_resource.version, new_resource.language, :install)
      else
        %w{'libasound2' 'libgtk2.0-0' 'libdbus-glib-1-2' 'libxt6'}.each do |pkg|
          package pkg
        end

        explode_tarball(cached_file, new_resource.path)
        node.set['firefox_package']['firefox']["#{new_resource.version}"]["#{new_resource.language}"] = new_resource.path.to_s
        unless new_resource.link.nil?
          if new_resource.link.kind_of?(Array)
            new_resource.link.each do |i|
              link i do
                to ::File.join(new_resource.path, 'firefox').to_s
              end
            end
          else
            link new_resource.link do
              to ::File.join(new_resource.path, 'firefox').to_s
            end
          end
        end
      end
    end

    def remove_package
      if munged_platform == 'win32'
        windows_installer(nil, new_resource.version, new_resource.language, :remove)
      else
        directory node['firefox_package']['firefox']["#{new_resource.version}"]["#{new_resource.language}"] do 
          recursive true
          action :delete
        end
      end
    end

  end
end
