class Service::OnTime < Service
  string :ontime_url, :api_key

  def receive_push
    if data['ontime_url'].to_s.empty?
      raise_config_error "No OnTime URL to connect to."
    elsif data['api_key'].to_s.empty?
      raise_config_error "No API Key."
    end

    # We're just going to send back the entire payload and process it in OnTime.
    http.url_prefix = data['ontime_url']

    # Hash the data, it has to be hexdigest in order to have the same hash value in .NET
    hash_data = Digest::SHA256.hexdigest(payload.to_json + data['api_key'])

    resp = http_get "api/version"
    version = JSON.parse(resp.body)['data']

    if version['major'] >= 11 and version['minor'] >= 0 and version['build'] >= 2
      result = http_post "api/github", :payload => payload.to_json, :hash_data => hash_data, :source => :github
    else
      raise_config_error "Unexpected API version. Please update to the latest version of OnTime to use this service."
    end

    verify_response(result)
  end

  def verify_response(res)
    case res.status
      when 200..299
      when 403, 401, 422 then raise_config_error("Invalid Credentials")
      when 404, 301, 302 then raise_config_error("Invalid URL")
      else raise_config_error("HTTP: #{res.status}")
    end
  end
end
