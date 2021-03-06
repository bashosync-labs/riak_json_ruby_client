## ------------------------------------------------------------------- 
## 
## Copyright (c) "2013" Basho Technologies, Inc.
##
## This file is provided to you under the Apache License,
## Version 2.0 (the "License"); you may not use this file
## except in compliance with the License.  You may obtain
## a copy of the License at
##
##   http://www.apache.org/licenses/LICENSE-2.0
##
## Unless required by applicable law or agreed to in writing,
## software distributed under the License is distributed on an
## "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
## KIND, either express or implied.  See the License for the
## specific language governing permissions and limitations
## under the License.
##
## -------------------------------------------------------------------

require 'rest-client'
require 'erb'
require 'yaml'

module RiakJson
  # Default hostname of the RiakJson test server
  RIAK_TEST_HOST = '127.0.0.1'
  # Default http port of the RiakJson test server
  RIAK_TEST_PORT = 8098

  # RiakJson::Client makes REST calls to the Riak Json API endpoints,
  # on behalf of a Collection.
  # Stores the details of a Riak/RiakJson HTTP connection (host, port),
  # and manages a cache of collection references.
  # Uses a pluggable ClientTransport component to make the actual HTTP requests.
  class Client
    attr_accessor :collection_cache
    attr_accessor :transport
    attr_accessor :host, :port
    
    def initialize(host=RiakJson::RIAK_TEST_HOST, port=RiakJson::RIAK_TEST_PORT)
      @collection_cache = {}
      @transport = RiakJson::ClientTransport.new
      @host = host
      @port = port
    end
    
    def base_collection_url
      "#{self.base_riak_json_url}/collection"
    end
    
    def base_riak_url
      "http://#{self.host}:#{self.port}"
    end

    def base_riak_json_url
      "#{self.base_riak_url}/document"
    end
        
    def collection(name)
      self.collection_cache[name] ||= RiakJson::Collection.new(name, self)
    end

    # Return the name of the Solr index (generated by RiakJson) for a collection
    def collection_index_name(collection_name)
      "#{collection_name}RJIndex"
    end
    
    # List all of the RiakJson collections on the riak cluster
    # This is different from a Riak 'list buckets' command. 
    # Instead of iterating over all the keys on the cluster, 'list collections'
    # only lists the custom RJ bucket types on the cluster (from the ring metadata)
    # Raw JSON that's returned by RJ:
    # 
    # <code>{"collections":[{"name":"collection1"},{"name":"collection2"}]}</code>
    # 
    # This is then mapped to a list of RiakJsonCollection instances.
    # @return [Array] List of +RiakJson::Collection+ instances that exist in the cluster.
    def collections
      result = self.transport.send_request("#{self.base_collection_url}", :get)
      collection_list = JSON.parse(result)['collections']
      collection_list.map { |ea| self.collection(ea['name'])}
    end
    
    def delete_json_object(collection_name, key)
      self.transport.send_request("#{self.base_collection_url}/#{collection_name}/#{key}", :delete)
    end

    def delete_schema(collection_name)
      self.transport.send_request("#{self.base_collection_url}/#{collection_name}/schema", :delete)
    end
    
    def get_json_object(collection_name, key)
      self.transport.send_request("#{self.base_collection_url}/#{collection_name}/#{key}", :get)
    end
    
    def get_query_all(collection_name, query_json)
      self.transport.send_request("#{self.base_collection_url}/#{collection_name}/query/all", :put, query_json)
    end
    
    def get_query_one(collection_name, query_json)
      self.transport.send_request("#{self.base_collection_url}/#{collection_name}/query/one", :put, query_json)
    end
    
    def get_schema(collection_name)
      self.transport.send_request("#{self.base_collection_url}/#{collection_name}/schema", :get)
    end
    
    # Sends a JSON document to a collection resource
    # If a key is specified, issues a PUT to that key
    # If key is nil, issues a POST to the collection, and returns the 
    #  key generated by RiakJson
    #
    # @param format [String]
    # @param key - can be nil
    # @param json [String]
    # @return [String] Returns the key for the inserted document
    def insert_json_object(collection_name, key, json)
      if key.nil?
        key = self.post_to_collection(collection_name, json)
      else
        self.transport.send_request("#{self.base_collection_url}/#{collection_name}/#{key}", :put, json)
        key
      end
    end
    
    # Load a config file in YAML format
    def self.load_config_file(config_file)
      config_file = File.expand_path(config_file)
      config_hash = YAML.load(ERB.new(File.read(config_file)).result)
    end
    
    # Perform an HTTP ping to the Riak cluster
    def ping
      response = self.transport.get_request("#{self.base_riak_url}/ping")
    end

    def post_to_collection(collection_name, json)
      response = self.transport.send_request("#{self.base_collection_url}/#{collection_name}", :post, json)
      if response.code == 201
        location = response.headers[:location]
        key = location.split('/').last
      else
        raise Exception, "Error inserting document into collection - key not returned"
      end
      key
    end
    
    def set_schema_json(collection_name, json)
      self.transport.send_request("#{self.base_collection_url}/#{collection_name}/schema", :put, json)
    end

    # Perform an arbitrary raw Solr query to a collection's index
    # @param [String] collection_name
    # @param [String] query_params Arbitrary query parameters that will be passed to /solr/collectionRJIndex?... endpoint
    # @return [String] JSON result from the query
    def solr_query_raw(collection_name, query_params)
      url = "#{self.base_riak_url}/search/query/#{self.collection_index_name(collection_name)}"
      self.transport.send_request(url, :get, query_params)
    end
    
    def update_json_object(collection_name, key, json)
      if key.nil? or key.empty?
        raise Exception, "Error: cannot update document, key missing"
      end
      self.transport.send_request("#{self.base_collection_url}/#{collection_name}/#{key}", :put, json)
    end
  end
end