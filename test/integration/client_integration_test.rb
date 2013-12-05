require 'helper'

describe "RiakJson Ruby Client" do
  context "connects to RiakJson" do
    it "can perform an HTTP /ping to the RiakJson cluster" do
      client = RiakJson::Client.new
      response = client.ping
      response.must_equal 'OK'
      response.code.must_equal 200
    end
    
    it "raises an ArgumentError on send_request with invalid HTTP method"
  end
  
  context "performs document Schema administration" do
    it "issues PUT requests to set a schema object for a collection" do
      client = test_client
      collection_name = 'test_collection'
      schema_json = [{
        :name => "field_one",
        :type => "string",
        :require => true
        }, {
        :name => "field_two",
        :type => "text",
        :require => false
        }].to_json
      response = client.set_schema_json(collection_name, schema_json)
      response.code.must_equal 204
    end

    it "issues GET requests to read a schema for an existing collection" do
      client = test_client
      collection_name = 'test_collection'
      response = client.get_schema(collection_name)
      response.code.must_equal 200
    end
    
    it "receives a 404 Exception when reading a non-existing schema" do
      # Note: A default schema is auto-created whenever a document is written to a collection
      # For a schema to not exist, no schemas could have been stored for that collection, and no documents inserted
      client = test_client
      collection_name = 'non-existing-collection'
      lambda { client.get_schema(collection_name) }.must_raise RestClient::ResourceNotFound  # 404
    end
    
    it "issues DELETE requests to remove a schema"
  end
end
