require 'faraday'
require 'json'

url = ENV['PAGERDUTY_URL']
api_key = ENV['PAGERDUTY_APIKEY_V2']
env_services = ENV['PAGERDUTY_SERVICES']
parsed_data = JSON.parse(env_services)

services = {}

parsed_data['services'].each do |key, value|
  services[key] = value
end

triggered = 0
acknowledged = 0

SCHEDULER.every '30s' do
  services.each do |key, value|
    conn = Faraday.new(url: "#{url}") do |faraday|
      faraday.request :url_encoded
      faraday.adapter Faraday.default_adapter
      faraday.headers['Content-type'] = 'application/json'
      faraday.headers['Authorization'] = "Token token=#{api_key}"
      faraday.headers['Accept'] = "application/vnd.pagerduty+json;version=2"
    end

    response = conn.get do |req|
      req.url '/incidents'
      req.params['service_ids[]'] = "#{value}"
      req.params['statuses[]'] = 'triggered'
      req.params['total'] = 'true'
    end
    puts "RESPONSE #{response.body}"
    json = JSON.parse(response.body)
    triggered = json['total'] == 'null' ? 0 : json['total']

    
    conn = Faraday.new(url: "#{url}") do |faraday|
      faraday.request :url_encoded
      faraday.adapter Faraday.default_adapter
      faraday.headers['Content-type'] = 'application/json'
      faraday.headers['Authorization'] = "Token token=#{api_key}"
      faraday.headers['Accept'] = "application/vnd.pagerduty+json;version=2"
    end

    response = conn.get do |req|
      req.url '/incidents'
      req.params['service_ids[]'] = "#{value}"
      req.params['statuses[]'] = 'acknowledged'
      req.params['total'] = 'true'
    end
    puts "RESPONSE #{response.body}"    
    json = JSON.parse(response.body)
    acknowledged = json['total'] == 'null' ? 0 : json['total']
    
    send_event("#{key}-triggered", value: triggered)
    send_event("#{key}-acknowledged", value: acknowledged)
  end
end
