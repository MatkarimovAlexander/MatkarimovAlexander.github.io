Jekyll::Hooks.register :posts, :post_render do |post|
  post.output.gsub!('<img src="media/', '<img src="/blog/media/')
end