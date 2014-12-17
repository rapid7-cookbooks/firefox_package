#
# Cookbook Name:: firefox_poise
# Recipe:: default
#
# Copyright (C) 2014 Rapid7, LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
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
    # Work-around for poise issue #8
    include Chef::Recipe::DSL
    actions(:install, :upgrade, :remove)

    attribute(:version, kind_of: String, name_attribute: true)
    attribute(:checksum, kind_of: String, default: lazy { self.upstream_file_checksum(platform, language, version) })
    attribute(:uri, kind_of: String, default: 'https://download-installer.cdn.mozilla.net/pub/firefox/releases')
    attribute(:language, kind_of: String, default: 'en-US')
    attribute(:platform, kind_of: String, default: lazy { node['platform'] })
  end

  class Provider::FirefoxPackage < Provider
    include Poise

    def action_install
      converge_by("installing Firefox #{new_resource.version}") do
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

    def generate_sha512_checksum(file)
      checksum_file(file, OpenSSL::Digest::SHA512.new)
    end

    def checksum_file(file, digest)
      File.open(file, 'rb') { |f| checksum_io(f, digest) }
    end

    def checksum_io(io, digest)
      while chunk = io.read(1024 * 8)
        digest.update(chunk)
      end
      digest.hexdigest
    end

    def validate_signing_key(release_file, gpg_key, signature)
      raise NotImplementedError, 'This is on my wishlist...'
    end

    def sha512_checksums_file
      sums_file = 'SHA512SUMS'

      remote_file ::File.join(Chef::Config[:file_cache_path], new_resource.version) do
        source "#{new_resource.uri}/#{new_resource.version}/#{sums_file}"
      end

      @sha512_checksums_file = ::File.join(Chef::Config[:file_cache_path], new_resource.version)
    end

    def upstream_checksums
      require 'csv'
      @upstream_checksums = Array.new

      checksums = CSV.read(sha512_checksums_file, 'r', {:headers => false, :col_sep => '\S+'})
      checksums.each do |i|
        @upstream_checksums << Hash[*i.join.split("  ").reverse]
      end
    end

    def platform_file_extension(platform)
      case platform
        when 'x86_64-linux' || 'linux-i686'
          @platform_file_extension = 'tar.bz2'
        when 'mac'
          @platform_file_extension = 'dmg'
        when 'win32' || 'windows'
          @platform_file_extension = 'zip'
      end
    end

    def upstream_file_checksum(platform, language, version)
      upstream_file_key = upstream_checksums.keys.select { |key| key.to_s.match(/^#{platform}\/#{language}\/firfox-#{version}\.#{platform_file_extension}/) }
      @upstream_file_checksum = upstream_checksums[:"#{upstream_file_key}"]
    end

    def install_package
      cached_file = ::File.join(Chef::Config[:file_cache_path], "firefox-#{new_resource.version}.#{platform_file_extension(new_resource.platform)}") 
      remote_file cached_file do
        source "#{new_resource.uri}/#{new_resource.version}/#{new_resource.platform}/#{new_resource.language}/firefox-#{new_resource.version}.#{platform_file_extension(new_resource.platform)}"
        checksum new_resource.checksum

        # TODO: Create a cache of the current sha512 value.
        not_if { new_resource.checksum == generate_sha512_checksum(cached_file) }
      end
    end

  end
end
