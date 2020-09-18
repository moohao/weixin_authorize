# encoding: utf-8

module WeixinAuthorize
  module Api
    module Media
      # 上传多媒体文件
      # http请求方式: POST/FORM
      # http://file.api.weixin.qq.com/cgi-bin/media/upload?access_token=ACCESS_TOKEN&type=TYPE
      # 支持传路径或者文件类型
      def upload_media(media, media_type)
        file = process_file(media)
        upload_media_url = "#{media_base_url}/upload"
        http_post(upload_media_url, {media: file}, {type: media_type}, "file")
      end

      # 目前仅仅把下载链接返回给第三方开发者，由第三方开发者处理下载
      def download_media_url(media_id)
        download_media_url = WeixinAuthorize.endpoint_url("file", "#{media_base_url}/get")
        params = URI.encode_www_form("access_token" => get_access_token,
                                     "media_id"     => media_id)
        download_media_url += "?#{params}"
        download_media_url
      end

      # 上传图文消息素材, 主要用于群发消息接口
      # {
      #    "articles": [
      #      {
      #        "thumb_media_id":"mwvBelOXCFZiq2OsIU-p",
      #        "author":"xxx",
      #        "title":"Happy Day",
      #        "content_source_url":"www.qq.com",
      #        "content":"content",
      #        "digest":"digest"
      #      },
      #      {
      #        "thumb_media_id":"mwvBelOXCFZiq2OsIU-p",
      #        "author":"xxx",
      #        "title":"Happy Day",
      #        "content_source_url":"www.qq.com",
      #        "content":"content",
      #        "digest":"digest"
      #      }
      #    ]
      # }
      # Option: author, content_source_url
      def upload_mass_news(news=[])
        upload_news_url = "#{media_base_url}/uploadnews"
        http_post(upload_news_url, {articles: news})
      end
      
      # 上传永久素材
      # https://api.weixin.qq.com/cgi-bin/material/add_material?access_token=ACCESS_TOKEN&type=TYPE
      #
      # return:
      # {
      #   "media_id":MEDIA_ID,
      #   "url":URL
      # }
      def add_material(media, media_type)
        file = process_file(media)
        upload_image_url = "#{material_base_url}/add_material"
        http_post(upload_image_url, {media: file}, {type: media_type})
      end
      
      # 删除永久素材
      # https://api.weixin.qq.com/cgi-bin/material/del_material?access_token=ACCESS_TOKEN
      #
      # return:
      # {
      #   "errcode":errcode,
      #   "errmsg":errmsg
      # }
      def del_material(media_id)
        upload_image_url = "#{material_base_url}/del_material"
        http_post(upload_image_url, {media_id: media_id})
      end
      
      # 新增永久图文素材
      # {
      #    "articles": [
      #      {
      #        "thumb_media_id":"mwvBelOXCFZiq2OsIU-p",
      #        "author":"xxx",
      #        "title":"Happy Day",
      #        "content_source_url":"www.qq.com",
      #        "content":"content",
      #        "digest":"digest"
      #      },
      #      {
      #        "thumb_media_id":"mwvBelOXCFZiq2OsIU-p",
      #        "author":"xxx",
      #        "title":"Happy Day",
      #        "content_source_url":"www.qq.com",
      #        "content":"content",
      #        "digest":"digest"
      #      }
      #    ]
      # }
      # Option: author, content_source_url
      def add_news(news=[])
        upload_news_url = "#{material_base_url}/add_news"
        http_post(upload_news_url, {articles: news})
      end

      # media_id: 需通过基础支持中的上传下载多媒体文件来得到
      # https://file.api.weixin.qq.com/cgi-bin/media/uploadvideo?access_token=ACCESS_TOKEN

      # return:
      # {
      #   "type":"video",
      #   "media_id":"IhdaAQXuvJtGzwwc0abfXnzeezfO0NgPK6AQYShD8RQYMTtfzbLdBIQkQziv2XJc",
      #   "created_at":1398848981
      # }
      def upload_mass_video(media_id, title="", desc="")
        video_msg = {
          "media_id"    => media_id,
          "title"       => title,
          "description" => desc
        }

        http_post("#{media_base_url}/uploadvideo", video_msg)
      end

      # 上传图文消息内的图片获取URL
      # https://api.weixin.qq.com/cgi-bin/media/uploadimg?access_token=ACCESS_TOKEN
      #
      # return:
      # {
      #   "url":  "http://mmbiz.qpic.cn/mmbiz/gLO17UPS6FS2xsypf378iaNhWacZ1G1UplZYWEYfwvuU6Ont96b1roYs CNFwaRrSaKTPCUdBK9DgEHicsKwWCBRQ/0"
      # }
      def upload_image(image)
        file = process_file(image)
        upload_image_url = "#{media_base_url}/uploadimg"
        http_post(upload_image_url, {media: file}, {type: 'image'}, 'file')
      end

      private
      
        def material_base_url
          "/material"
        end
      
        def media_base_url
          "/media"
        end

        def process_file(media)
          return media if media.is_a?(File) && jpep?(media)

          media_url = media

          if http?(media_url) # remote
            media = download_remote_file(media_url)
          else # local
            media = media.is_a?(File) ? media : File.new(media_url)
          end
          media
        end

        def http?(uri)
          return false if !uri.is_a?(String)
          uri = URI.parse(uri)
          uri.scheme =~ /^https?$/
        end

        def jpep?(file)
          content_type = if file.respond_to?(:content_type)
              file.content_type
            else
              content_type(file.path)
            end
          !(content_type =~ /jpeg/).nil?
        end

        def content_type(media_path)
          MIME::Types.type_for(media_path).first.content_type
        end

        def download_remote_file(url)
          base_path = "#{Rails.root}/tmp/download_remote_file"
          if File.exist?(base_path)
            FileUtils.rm_rf(Dir["#{base_path}/*"])
          else
            Dir.mkdir(base_path)
          end
          local_path = "#{base_path}/#{Time.now.to_i}_#{rand(999_999)}.#{url.split('.').last}"
          require 'open-uri'
          URI.open(url) do |image|
            File.open(local_path, 'wb') do |file|
              file.write(image.read)
            end
          end
          raise 'download remote file faid' unless File.exist?(local_path)
          File.new(local_path)
        end
    end
  end
end
