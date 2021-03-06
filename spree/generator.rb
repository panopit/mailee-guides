# encoding: utf-8

require 'set'
require 'builder'

module Spree
  class Generator
    DOCTYPE = %(<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN" "http://www.w3.org/TR/html4/strict.dtd">)
    attr_reader :output, :view_path, :view, :guides_dir

    def initialize(output = nil)
      @guides_dir = File.join(File.dirname(__FILE__), '..')

      @output = output || File.join(@guides_dir, "output")
      
      @only = ENV["ONLY"]
      @only = ARGV.join(",")if ARGV.length > 0

      unless @only
        FileUtils.rm_r(@output) if File.directory?(@output)
        FileUtils.mkdir_p(@output)
      end

      @view_path = File.join(@guides_dir, "source")
    end

    def generate
      guides = Dir.entries(view_path).find_all {|g| g =~ /textile$/ }

      if @only
        only = @only.split(",").map{|x| x.strip }.map {|o| "#{o}.textile" }
        guides = guides.find_all {|g| only.include?(g) }
        puts "GENERATING ONLY #{guides.inspect}"
      end

      guides.each do |guide|
        generate_guide(guide)
      end

      generate_sitemap(guides)

      # Copy images and css files to html directory
      FileUtils.cp_r File.join(guides_dir, 'images'), File.join(@output, 'images')
      FileUtils.cp_r File.join(guides_dir, 'files'), File.join(@output, 'files')
    end

    def generate_sitemap(guides)
      puts "Generating sitemap.xml"
      builder = Builder::XmlMarkup.new

      xml = builder.urlset({"xmlns:xsi" => "http://www.w3.org/2001/XMLSchema-instance", "xmlns" => "http://www.sitemaps.org/schemas/sitemap/0.9", "xsi:schemaLocation" => "http://www.sitemaps.org/schemas/sitemap/0.9 http://www.sitemaps.org/schemas/sitemap/0.9/sitemap.xsd"}) do |urlset|
        urlset.url do |url|
          url.loc "http://help.mailee.me/index.html"
          url.lastmod Date.today
          url.changefreq "weekly"
          url.priority 1
        end
        for guide in guides
          guide =~ /(.*?)(\.erb)?\.textile/
          name = $1
          urlset.url do |url|
            url.loc "http://help.mailee.me/#{name}"
            url.lastmod Date.today
            url.changefreq "weekly"
            url.priority 0.5
          end
        end
      end
      file = File.join(output, "sitemap.xml")
      File.open(file, 'w'){|f| f.write "<?xml version='1.0' encoding='UTF-8'?>#{xml.to_s}" }
    end

    def generate_guide(guide)
      guide =~ /(.*?)(\.erb)?\.textile/
      name = $1

      puts "Generating #{name}"

      file = File.join(output, "#{name}.html")
      File.open(file, 'w') do |f|
        @view = ActionView::Base.new(view_path)
        @view.extend(Helpers)

        if guide =~ /\.erb\.textile/
          # Generate the erb pages with textile formatting - e.g. index/authors
          result = view.render(:layout => 'layout', :file => name)
          f.write(DOCTYPE + textile(result))
        else
          body = File.read(File.join(view_path, guide))
          body = set_header_section(body, @view)
          body = set_index(body, @view)  

          result = view.render(:layout => 'layout', :text => textile(body))    
          f.write(DOCTYPE + result)
          warn_about_broken_links(result)
        end
      end
    end

    def set_header_section(body, view)
      new_body = body.gsub(/(.*?)endprologue\./m, '').strip
      header = $1
      header =~ /h2\.(.*)/
      page_title = $1.strip

      header = textile(header)

      view.content_for(:page_title) { page_title }
      view.content_for(:header_section) { header }
                     
      new_body
    end  
    
    def set_index(body, view)
      index = <<-INDEX
      <div id="subCol">
        <h3 class="chapter"><img src="images/chapters_icon.gif" alt="Capítulos">Cap&iacute;tulos</h3>
        <ol class="chapters">
      INDEX

      i = Indexer.new(body)
      i.index

      # Set index for 2 levels
      i.level_hash.each do |key, value|
        link = view.content_tag(:a, :href => key[:id]) { textile(key[:title]) }

        children = value.keys.map do |k|
          l = view.content_tag(:a, :href => k[:id]) { textile(k[:title]) }
          view.content_tag(:li, l)
        end

        children_ul = view.content_tag(:ul, children)

        index << view.content_tag(:li, link + children_ul)
      end

      index << '</ol>'
      index << '</div>'

      view.content_for(:index_section) { index }

      i.result
    end

    def textile(body)
      # If the issue with notextile is fixed just remove the wrapper.
      with_workaround_for_notextile(body) do |body|
        t = RedCloth.new(body)
        t.hard_breaks = false
        t.to_html(:notestuff, :plusplus, :code, :tip)
      end
    end

    # For some reason the notextile tag does not always turn off textile. See
    # LH ticket of the security guide (#7). As a temporary workaround we deal
    # with code blocks by hand.
    def with_workaround_for_notextile(body)
      code_blocks = []
      body.gsub!(%r{<(yaml|shell|ruby|erb|html|sql|plain)>(.*?)</\1>}m) do |m|
        es = ERB::Util.h($2)
        css_class = ['erb', 'shell'].include?($1) ? 'html' : $1
        code_blocks << %{<div class="code_container"><code class="#{css_class}">#{es}</code></div>}
        "\ndirty_workaround_for_notextile_#{code_blocks.size - 1}\n"
      end
      
      body = yield body
      
      body.gsub(%r{<p>dirty_workaround_for_notextile_(\d+)</p>}) do |_|
        code_blocks[$1.to_i]
      end
    end

    def warn_about_broken_links(html)
      # Textile generates headers with IDs computed from titles.
      anchors  = Set.new(html.scan(/<h\d\s+id="([^"]+)/).flatten)
      # Also, footnotes are rendered as paragraphs this way.
      anchors += Set.new(html.scan(/<p\s+class="footnote"\s+id="([^"]+)/).flatten)
      
      # Check fragment identifiers.
      html.scan(/<a\s+href="#([^"]+)/).flatten.each do |fragment_identifier|
        next if fragment_identifier == 'mainCol' # in layout, jumps to some DIV
        unless anchors.member?(fragment_identifier)
          puts "BROKEN LINK: ##{fragment_identifier}"
        end
      end
    end
  end
end
