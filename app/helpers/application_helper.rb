module ApplicationHelper
  # Browsers cache favicons hard, so the URL changes whenever the icon does.
  def favicon_path
    @@favicon_path ||= "/icon.svg?v=#{Digest::MD5.file(Rails.public_path.join('icon.svg')).hexdigest.first(8)}"
  end

  # Mount point for a Vue page component; see app/frontend/entrypoints/application.ts.
  def vue_page(name, props)
    tag.div(id: "app", data: { vue_page: name, props: camelize(props) })
  end
end
