require "multi_json"

module Rulers
  module Model
    class FileModel
      @@cache = {}

      def initialize(filename)
        @filename = filename

        # If filename is "dir/37.json", @id is 37
        basename = File.split(filename)[-1]
        @id = File.basename(basename, ".json").to_i

        obj = File.read(filename)
        @hash = MultiJson.decode(obj)
      end

      def [](name)
        @hash[name.to_s]
      end

      def []=(name, value)
        @hash[name.to_s] = value
      end

      def self.find(id)
        path = "db/quotes/#{id}.json"
        begin
          if should_be_cached?(id)
            @@cache[path][:file_model]
          else
            @@cache[path] = Hash.new
            @@cache[path][:cache_time] = Time.now
            @@cache[path][:file_model] = FileModel.new(path)
          end
        rescue => e
          raise Rulers::Exceptions::RecordNotFound.new("Record was not found: " << e.message)
        end
      end

      def self.all
        files = Dir["db/quotes/*.json"]
        files.map { |f| FileModel.new f }
      end

      def self.create(attrs)
        hash = {}
        hash["submitter"] = attrs["submitter"] || ""
        hash["quote"] = attrs["quote"] || ""
        hash["attribution"] = attrs["attribution"] || ""

        files = Dir["db/quotes/*.json"]
        names = files.map { |f| f.split("/")[-1] }
        highest = names.map { |b| b.to_i }.max
        id = highest + 1

        File.open("db/quotes/#{id}.json", "w") do |f|
          f.write <<-TEMPLATE
            {
              "submitter": "#{hash["submitter"]}",
              "quote": "#{hash["quote"]}",
              "attribution": "#{hash["attribution"]}"
            }
          TEMPLATE
        end
        
        FileModel.new("db/quotes/#{id}.json") 
      end

      def self.update(id, attrs)
        # Tested using the following POST
        # curl "http://localhost:3001/quotes/update_quote" -d id=6 -d attribs='{"quote": "testing"}'
        file = File.read("db/quotes/#{id}.json")
        hash = MultiJson.decode(file)
        attributes = MultiJson.decode(attrs)
        hash = hash.merge(attributes)
        save(id, hash)
      end

      def self.save(id, hash_data)
        json_data = MultiJson.encode(hash_data)
        File.open("db/quotes/#{id}.json", "w") do |f|
          f.write json_data
        end
      end

      def self.find_all_by_submitter(attrs)
        attributes = MultiJson.decode(attrs)
        results = []
        all.each do |file|
          results << file if file[:submitter] == attributes["submitter"]
        end
        results
      end

      def self.should_be_cached?(id)
        path = "db/quotes/#{id}.json"
        begin
          @@cache[path] && @@cache[path][:cache_time] >= File.mtime(path) ? true : false
        rescue
          false
        end
      end

      def self.find_all_by_attribute(attribute, attrs)
        attributes = MultiJson.decode(attrs)
        results = []
        all.each do |file|
          results << file if file[attribute.to_sym] == attributes[attribute.to_s]
        end
        results
      end

      def self.method_missing(method_name, *args, &block)
        if method_name.to_s =~ /^find_all_by_(.*)/
          find_all_by_attribute($1, *args)
        else
          super
        end
      end

      def self.respond_to_missing?(method_name, include_private = false)
        method_name.to_s.start_with?('find_all_by_') || super
      end

    end
  end
end
