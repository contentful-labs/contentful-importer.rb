module Contentful
  module Exporter
    module Wordpress
      class Comment < Post

        attr_reader :post, :config

        def initialize(post, config)
          @post = post
          @config = config
        end

        def comments_extractor
          puts 'Extracting post comments...'
          create_directory("#{config.entries_dir}/comment")
          extract_comments
        end

        private

        def extract_comments
          post.xpath('wp:comment').each_with_object([]) do |comment, comments|
            comment_data = extracted_data(comment)
            write_json_to_file("#{config.entries_dir}/comment/#{entry_id(comment)}.json", comment_data)
            comments << comment_data
          end
        end

        def extracted_data(comment)
          {
              id: entry_id(comment),
              content: content(comment),
              author: author(comment),
              author_email: author_email(comment),
              author_url: author_url(comment),
              created_at: created_at(comment)
          }
        end

        def entry_id(comment)
          "#{post_id(post)}_#{id(comment)}"
        end

        def id(comment)
          comment.xpath('wp:comment_id').text
        end

        def content(comment)
          comment.xpath('wp:comment_content').text
        end

        def author(comment)
          comment.xpath('wp:comment_author').text
        end

        def author_email(comment)
          comment.xpath('wp:comment_author_email').text
        end

        def created_at(comment)
          comment.xpath('wp:comment_date').text
        end

        def author_url(comment)
          comment.xpath('wp:comment_author_url').text
        end

      end
    end
  end
end