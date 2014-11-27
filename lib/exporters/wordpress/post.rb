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
          create_directory("#{config.entries_dir}/post")
          extract_posts
        end

        def post_id(post)
          'post_' + post.xpath('wp:post_id').text
        end

        private

        def extract_posts
          posts.each_with_object([]) do |post, posts|
            normalized_post = extract_data(post)
            write_json_to_file("#{config.entries_dir}/post/#{post_id(post)}.json", normalized_post)
            posts << normalized_post
          end
        end

        def posts
          xml.xpath('//item').to_a
        end

        def extract_data(post)
          linked_comments = link_entry(comments(post))
          linked_tags = link_entry(tags(post))
          linked_categories = link_entry(categories(post))
          post = {id: post_id(post), title: title(post), wordpress_url: url(post), content: content(post), attachment: link_asset(attachment(post))}
          post.merge!(comments: linked_comments) unless linked_comments.empty?
          post.merge!(tags: linked_tags) unless linked_tags.empty?
          post.merge!(categories: linked_categories) unless linked_categories.empty?
          post
        end

        def attachment(post)
          PostAttachment.new(post, config).attachment_extractor
        end

        def comments(post)
          Comment.new(post, config).comments_extractor
        end

        def tags(post)
          PostCategoryDomain.new(xml, post, config).extract_tags
        end

        def categories(post)
          PostCategoryDomain.new(xml, post, config).extract_categories
        end

        def title(post)
          post.xpath('title').text
        end

        def url(post)
          post.xpath('link').text
        end

        def content(post)
          post.xpath('content:encoded').text
        end

        def created_at(post)
          post.xpath('wp:post_date').text
        end

        def comment_status(post)
          post.xpath('wp:comment_status').text
        end

      end
    end
  end
end
