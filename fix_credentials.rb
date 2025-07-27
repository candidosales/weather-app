#!/usr/bin/env ruby

# Script to fix the corrupted credentials file
require 'rails'
require 'rails/all'

# Load the Rails application
Rails.application = Class.new(Rails::Application)
Rails.application.config.load_defaults Rails::VERSION::STRING.to_f

# Read current credentials
current_credentials = Rails.application.credentials.config

# Fix the API key
api_key = current_credentials.delete(:"69openweather_api_key") || current_credentials[:openweather_api_key]

if api_key
  # Create new credentials hash with fixed key
  new_credentials = current_credentials.dup
  new_credentials[:openweather_api_key] = api_key

  puts "Found API key: #{api_key}"
  puts "Fixing credentials..."

  # Write the corrected credentials
  Rails.application.credentials.write(new_credentials.to_yaml)
  puts "Credentials fixed successfully!"
else
  puts "No API key found in credentials"
end
