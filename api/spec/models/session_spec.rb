# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Session do
  describe '#invite_url' do
    subject(:url) { described_class.new(invite_token: 'abc123').invite_url }

    it 'points at the web app, where the candidate page lives' do
      with_env('WEB_APP_URL' => 'https://app.example.com', 'APP_BASE_URL' => 'https://api.example.com') do
        expect(url).to eq('https://app.example.com/interview/abc123')
      end
    end

    it 'still reads the old APP_BASE_URL name' do
      with_env('WEB_APP_URL' => nil, 'APP_BASE_URL' => 'https://app.example.com') do
        expect(url).to eq('https://app.example.com/interview/abc123')
      end
    end

    it 'defaults to the local web app, not the API' do
      with_env('WEB_APP_URL' => nil, 'APP_BASE_URL' => nil) do
        expect(url).to eq('http://localhost:5173/interview/abc123')
      end
    end

    it 'does not double the slash when the URL ends with one' do
      with_env('WEB_APP_URL' => 'https://app.example.com/') do
        expect(url).to eq('https://app.example.com/interview/abc123')
      end
    end
  end
end
