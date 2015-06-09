control_group 'Firefox Installation' do
  if platform?('ubuntu')
    control 'latest-esr' do
      subject(:latest_esr) { command('/opt/firefox/latest-esr_en-US/firefox --version') }
      it 'is installed and symlinked' do
        expect(file('/usr/bin/firefox-latest-esr')).to be_symlink
        expect(file('/usr/bin/firefox-latest-esr')).to be_linked_to('/opt/firefox/latest-esr_en-US/firefox')
        expect(file('/opt/firefox/latest-esr_en-US/firefox')).to be_executable
        expect(latest_esr.exit_status).to eq(0)
      end
    end

    control 'latest' do
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

    control '37.0' do
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
  elsif platform?('windows')
    control 'latest-esr' do
      subject(:latest_esr) { command('') }
    end
  end
end
