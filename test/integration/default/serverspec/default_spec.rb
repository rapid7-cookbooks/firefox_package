require 'spec_helper'

describe 'Firefox Installation' do
  unless os[:family] == 'windows'
    context 'latest_esr' do
      subject(:latest_esr) { command('/opt/firefox/latest-esr_en-US/firefox --version') }
      it 'is installed and symlinked' do
        expect(file('/usr/bin/firefox-latest-esr')).to be_symlink
        expect(file('/usr/bin/firefox-latest-esr')).to be_linked_to('/opt/firefox/latest-esr_en-US/firefox')
        expect(file('/opt/firefox/latest-esr_en-US/firefox')).to be_executable
        expect(latest_esr.exit_status).to eq(0)
      end
    end

    context 'latest' do
      subject(:latest) { command('/opt/firefox/latest_en-US/firefox --version') }

      it 'is installed and symlinked' do
        expect(file('/usr/bin/firefox-latest')).to be_symlink
        expect(file('/usr/bin/firefox-latest')).to be_linked_to('/opt/firefox/latest_en-US/firefox')
        expect(file('/opt/firefox/latest_en-US/firefox')).to be_executable
      end

      it 'is functional when invoked' do
        expect(latest.exit_status).to eq(0)
      end
    end

    context '37.0' do
      subject(:specified_version) { command('/opt/firefox/37.0_en-US/firefox --version') }

      it 'is installed and symlinked' do
        expect(file('/usr/bin/firefox-37.0')).to be_symlink
        expect(file('/usr/bin/firefox-37.0')).to be_linked_to('/opt/firefox/37.0_en-US/firefox')
        expect(file('/opt/firefox/37.0_en-US/firefox')).to be_executable
      end

      it 'is functional when invoked' do
        expect(specified_version.exit_status).to eq(0)
      end

      it 'is the correct version of Firefox'do
        expect(specified_version.stdout).to match(/Mozilla Firefox 37.0/)
      end
    end
  else
    subject 'latest-esr' do
      let(:bin_path) { 'C:\Program Files (x86)\Mozilla Firefox\latest-esr_en-US\firefox.exe' }
      subject(:latest_esr) { command( "\"#{bin_path}\" --version") }

      it 'is installed' do
        expect(file(bin_path)).to be_file
      end
    end

    subject 'latest' do
      let(:bin_path) {'C:\Program Files (x86)\Mozilla Firefox\latest_en-US\firefox.exe' }
      subject(:latest_esr) { command( "\"#{bin_path}\" --version") }

      it 'is installed' do
        expect(file(bin_path)).to be_file
      end
    end

    subject '37.0' do
      let(:bin_path) {'C:\Program Files (x86)\Mozilla Firefox\37.0_en-US\firefox.exe' }
      subject(:specified_version) { command( "\"#{bin_path}\" --version") }

      it 'is installed' do
        expect(file(bin_path)).to be_file
      end

      # This seems to be broken for Windows.
      xit 'is functional when invoked' do
        expect(specified_version.stdout).to match(/Mozilla Firefox 37.0/)
      end

      # This seems to be broken
      xit 'is the correct version of Firefox' do
        expect(specified_version.stdout).to be_version('37.0')
      end
    end
  end
end
