module Contentful
  module Exporter
    module Wordpress
      class Post < Blog

        attr_reader :xml, :config

        def initialize(xml, config)
          @xml = xml
          @config = config
        end

        def post_extractor
          puts 'Extracting posts...'
          create_directory("#{config.entries_dir}/post")
          extract_posts
        end

        def post_id(post)
          'post_' + post.xpath('wp:post_id').text
        end

        private

        def extract_posts
          posts.each_with_object([]) do |post_xml, posts|
            normalized_post = extract_data(post_xml)
            write_json_to_file("#{config.entries_dir}/post/#{post_id(post_xml)}.json", normalized_post)
            posts << normalized_post
          end
        end

        def posts
          xml.xpath('//item').to_a
        end

        ## TODO REFACTOR - MOVE TO SEPARATE CLASS
        def extract_data(xml_post)
          linked_comments = link_entry(comments(xml_post))
          linked_tags = link_entry(tags(xml_post))
          linked_categories = link_entry(categories(xml_post))
          created = Date.strptime(created_at(xml_post))
          post_entry = {id: post_id(xml_post), title: title(xml_post), wordpress_url: url(xml_post), content: content(xml_post), created_at: created}
          post_entry.merge!(attachment: link_asset(attachment(xml_post))) unless attachment(xml_post).nil?
          post_entry.merge!(comments: linked_comments) unless linked_comments.empty?
          post_entry.merge!(tags: linked_tags) unless linked_tags.empty?
          post_entry.merge!(categories: linked_categories) unless linked_categories.empty?
          post_entry
        end

        def attachment(xml_post)
          PostAttachment.new(xml_post, config).attachment_extractor
        end

        def comments(xml_post)
          Comment.new(xml_post, config).comments_extractor
        end

        def tags(xml_post)
          PostCategoryDomain.new(xml, xml_post, config).extract_tags
        end

        def categories(xml_post)
          PostCategoryDomain.new(xml, xml_post, config).extract_categories
        end

        def title(xml_post)
          xml_post.xpath('title').text
        end

        def url(xml_post)
          xml_post.xpath('link').text
        end

        def content(xml_post)
          xml_post.xpath('content:encoded').text
        end

        def created_at(xml_post)
          xml_post.xpath('wp:post_date').text
        end

        def comment_status(xml_post)
          xml_post.xpath('wp:comment_status').text
        end

      end
    end
  end
end
