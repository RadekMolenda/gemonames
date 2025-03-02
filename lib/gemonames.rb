require "gemonames/version"
require "values"
require "faraday"
require "faraday_middleware"

module Gemonames
  module_function
  BASE_API_URL = "http://api.geonames.org"

  def client(username:, connection: nil)
    connection ||= build_connection(username: username)
    ApiClient.new(connection)
  end

  def build_connection(username:)
    Faraday.new(url: BASE_API_URL) do |faraday|
      faraday.response :json
      faraday.params[:username] = username
      faraday.adapter Faraday.default_adapter
    end
  end

  class ApiClient
    attr_reader :connection

    def initialize(connection)
      @connection = connection
    end

    def search(query, country_code:, limit: 10)
      perform_search_request(
        query: query, country_code: country_code, max_rows: limit
      ).fetch("geonames").map { |result|
        wrap_in_search_result(result)
      }
    end

    def find(query, country_code:)
      results = perform_search_request(
        query: query, country_code: country_code, max_rows: 1
      ).fetch("geonames")

      if results.any?
        wrap_in_search_result(results.first)
      else
        NoResultFound.new
      end
    end

    private

    def perform_search_request(query:, country_code:, max_rows:)
      results = connection.get do |request|
        request.url "/searchJSON".freeze
        request.params[:q] = query
        request.params[:country] = country_code
        request.params[:maxRows] = max_rows
        request.params[:style] = "short".freeze
      end

      results.body
    end

    def wrap_in_search_result(result)
      SearchResult.with(
        geoname_id: result.fetch("geonameId".freeze),
        name: result.fetch("name".freeze),
        country_code: result.fetch("countryCode".freeze),
      )
    end
  end

  SearchResult = Value.new(:geoname_id, :name, :country_code) do
    def result?
      true
    end
  end

  class NoResultFound
    def geoname_id() end
    def name() end
    def country_code() end

    def result?
      false
    end
  end
end
